part of 'found_register_page.dart';

class _PlaceSearchStep extends StatefulWidget {
  const _PlaceSearchStep({
    super.key,
    required this.onBack,
    required this.onClose,
    required this.onPickLocation,
  });

  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<_LocationSelection> onPickLocation;

  @override
  State<_PlaceSearchStep> createState() => _PlaceSearchStepState();
}

class _PlaceSearchStepState extends State<_PlaceSearchStep>
    with _LocationRegionResolver {
  final _queryController = TextEditingController();
  @override
  KakaoMapController? get _mapController => null;
  final _searchWebViewController = WebViewController();
  KakaoPlaceSearchService? _searchService;
  List<KeywordAddress> _places = [];
  KeywordAddress? _selectedPlace;
  String _keyword = '';
  String? _message;
  Future<void>? _searchSdkInitialization;
  int _page = 1;
  bool _hasNext = false;
  bool _ready = false;
  bool _searching = false;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _loadSearchSdk();
  }

  String get _searchSdkHtml {
    final appKey = Uri.encodeComponent(AuthRepository.instance.appKey);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?autoload=false&appkey=$appKey&libraries=services"></script>
  <script>
    window.foundPlaceSearchReady = false;
    window.foundPlaceSearchResults = {};
    kakao.maps.load(function() {
      window.foundPlaceSearchReady = true;
    });
  </script>
</head>
<body></body>
</html>
''';
  }

  Future<void> _loadSearchSdk() async {
    try {
      await _searchWebViewController.setJavaScriptMode(
        JavaScriptMode.unrestricted,
      );
      await _searchWebViewController.setBackgroundColor(Colors.transparent);
      await _searchWebViewController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _initializeSearchService(),
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            debugPrint('[카카오 장소 검색 WebView] ${error.description}');
            setState(() => _message = '장소 검색을 불러오지 못했습니다. 연결을 확인해 주세요.');
          },
        ),
      );
      await _searchWebViewController.loadHtmlString(
        _searchSdkHtml,
        baseUrl: AuthRepository.instance.baseUrl,
      );
    } catch (error) {
      debugPrint('[카카오 장소 검색 WebView] $error');
      if (mounted) {
        setState(() => _message = '장소 검색을 불러오지 못했습니다. 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _initializeSearchService() {
    if (_ready) return Future<void>.value();
    final pendingInitialization = _searchSdkInitialization;
    if (pendingInitialization != null) return pendingInitialization;

    final initialization = _initializeSearchServiceOnce();
    _searchSdkInitialization = initialization;
    return initialization;
  }

  Future<void> _initializeSearchServiceOnce() async {
    _searchService?.dispose();
    final service = KakaoPlaceSearchService.withJavaScript(
      run: _searchWebViewController.runJavaScript,
      evaluate: _searchWebViewController.runJavaScriptReturningResult,
    );
    _searchService = service;
    try {
      await service.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      debugPrint('[카카오 장소 검색 초기화] $error');
      if (mounted) {
        setState(() => _message = '장소 검색을 준비하지 못했습니다. 다시 시도해 주세요.');
      }
    } finally {
      _searchSdkInitialization = null;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _searchService?.dispose();
    super.dispose();
  }

  Future<void> _search({bool loadMore = false}) async {
    final keyword = loadMore ? _keyword : _queryController.text.trim();
    if (_searching || _selecting || keyword.isEmpty) return;
    final page = loadMore ? _page + 1 : 1;
    setState(() {
      _searching = true;
      _message = null;
      if (!loadMore) {
        _keyword = keyword;
        _places = [];
        _selectedPlace = null;
        _hasNext = false;
      }
    });
    try {
      if (!_ready) await _initializeSearchService();
      if (!mounted || !_ready) return;
      FocusScope.of(context).unfocus();
      final service = _searchService;
      if (service == null) {
        throw StateError('카카오 장소 검색 서비스가 초기화되지 않았습니다.');
      }
      final result = await service.search(keyword, page: page);
      if (!mounted) return;
      setState(() {
        _places = loadMore ? [..._places, ...result.places] : result.places;
        _page = page;
        _hasNext = result.hasNext;
        if (_places.isEmpty) {
          _message = '검색 결과가 없습니다. 다른 건물명이나 장소명으로 검색해 주세요.';
        }
      });
    } on StateError catch (error) {
      debugPrint('[카카오 장소 검색] $error');
      if (!mounted) return;
      setState(() => _message = '장소 검색을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.');
    } catch (error) {
      debugPrint('[카카오 장소 검색] $error');
      if (!mounted) return;
      setState(() => _message = '검색하지 못했습니다. 연결을 확인하고 다시 검색해 주세요.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  LatLng? _coordinates(KeywordAddress place) {
    final latitude = double.tryParse(place.y ?? '');
    final longitude = double.tryParse(place.x ?? '');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  String _address(KeywordAddress place) {
    final road = place.roadAddressName?.trim() ?? '';
    return road.isNotEmpty ? road : place.addressName?.trim() ?? '';
  }

  void _preview(KeywordAddress place) {
    final location = _coordinates(place);
    if (location == null || _selecting) return;
    setState(() => _selectedPlace = place);
  }

  Future<void> _confirm() async {
    final place = _selectedPlace;
    if (place == null || _selecting || _searching) return;
    final location = _coordinates(place);
    if (location == null) return;
    setState(() => _selecting = true);
    try {
      final region = await _resolveRegion(location);
      if (!mounted) return;
      if (region.sido.isEmpty || region.sigungu.isEmpty) {
        throw StateError('장소의 행정구역 정보를 확인할 수 없습니다.');
      }
      widget.onPickLocation(
        _LocationSelection(
          latLng: location,
          label: [
            place.placeName?.trim() ?? '',
            _address(place),
          ].where((part) => part.isNotEmpty).join(' · '),
          sido: region.sido,
          sigungu: region.sigungu,
          eupmyeondong: region.eupmyeondong,
        ),
      );
    } catch (error) {
      debugPrint('[카카오 장소 선택] $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보를 불러오지 못했습니다. 다시 선택해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = _selectedPlace == null
        ? null
        : _coordinates(_selectedPlace!);
    return _StepShell(
      title: '습득 장소 검색',
      onBack: widget.onBack,
      onClose: widget.onClose,
      bottom: _PrimaryButton(
        text: _selecting ? '위치 확인 중...' : '이 장소로 선택',
        enabled: selectedLocation != null && !_selecting && !_searching,
        onTap: _confirm,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '건물명이나 장소명 검색 (예: 김포공항)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '검색',
                  onPressed:
                      !_searching &&
                          !_selecting &&
                          _queryController.text.trim().isNotEmpty
                      ? () => _search()
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_message != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_message!)),
          SizedBox(
            width: 2,
            height: 2,
            child: IgnorePointer(
              child: WebViewWidget(controller: _searchWebViewController),
            ),
          ),
          Expanded(
            child: _places.isEmpty
                ? Center(
                    child: Text(
                      _keyword.isEmpty ? '장소를 검색하고 결과에서 습득 위치를 선택해 주세요.' : '',
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _places.length + (_hasNext ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _places.length) {
                        return TextButton(
                          onPressed: _searching || _selecting
                              ? null
                              : () => _search(loadMore: true),
                          child: const Text('검색 결과 더 보기'),
                        );
                      }
                      final place = _places[index];
                      final selected = identical(place, _selectedPlace);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        selected: selected,
                        selectedTileColor: const Color(0xFFEEF2FF),
                        title: Text(
                          place.placeName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            place.categoryGroupName ?? '',
                            _address(place),
                            place.phone ?? '',
                          ].where((part) => part.isNotEmpty).join('\n'),
                        ),
                        trailing: Icon(
                          selected ? Icons.check_circle : Icons.place_outlined,
                        ),
                        enabled:
                            !_searching &&
                            !_selecting &&
                            _coordinates(place) != null,
                        onTap: () => _preview(place),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
