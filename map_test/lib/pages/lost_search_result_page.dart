import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../lost_models/lost_item.dart';
import '../lost_models/lost_search_filter.dart';
import '../utils/current_position.dart';
import 'distance_reference_map_page.dart';

enum _DistanceReferenceChoice { currentLocation, map }

enum LostSearchSortOption {
  similarity('유사도순'),
  nearest('가까운순'),
  newest('최신순'),
  oldest('오래된순');

  const LostSearchSortOption(this.label);

  final String label;
}

class LostSearchResultPage extends StatefulWidget {
  const LostSearchResultPage({super.key, required this.filter});

  final LostSearchFilter filter;

  @override
  State<LostSearchResultPage> createState() => _LostSearchResultPageState();
}

class _LostSearchResultPageState extends State<LostSearchResultPage> {
  static const String collectionName = 'found_items';
  static const int _pageSize = 20;
  static final RegExp _searchSeparator = RegExp(r'[^0-9a-zA-Z가-힣]+');

  LostSearchSortOption selectedSort = LostSearchSortOption.similarity;
  DistanceReference? _distanceReference;
  final List<LostItem> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  Object? _loadError;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '검색 결과',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _items.isEmpty) {
      return _messageView(
        icon: Icons.error_outline,
        title: '검색 결과를 불러오지 못했습니다',
        message: '$_loadError',
        action: OutlinedButton(
          onPressed: _loadNextPage,
          child: const Text('다시 시도'),
        ),
      );
    }

    final List<LostItem> items = _sortedItems(_items);
    return Column(
      children: [
        _resultHeader(items.length),
        Expanded(child: _buildResultList(items)),
      ],
    );
  }

  Widget _buildResultList(List<LostItem> items) {
    if (items.isEmpty) {
      return _messageView(
        icon: Icons.search_off_outlined,
        title: _hasMore ? '이번 페이지에 일치하는 결과가 없습니다' : '검색 결과가 없습니다',
        message: _hasMore
            ? '다음 페이지를 불러오면 추가 문서를 검색합니다.'
            : '필터 조건을 줄이거나 다른 키워드로 검색해보세요.',
        action: _hasMore ? _loadMoreButton() : null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _paginationFooter();
        }

        return _LostItemCard(
          item: items[index],
          formatDate: _formatDate,
          showDistance: selectedSort == LostSearchSortOption.nearest,
          distanceMeters: _distanceTo(items[index]),
        );
      },
    );
  }

  Widget _paginationFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Column(
        children: [
          const Text('추가 결과를 불러오지 못했습니다.'),
          const SizedBox(height: 8),
          _loadMoreButton(),
        ],
      );
    }
    if (_hasMore) {
      return _loadMoreButton();
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Text('모든 검색 결과를 불러왔습니다.')),
    );
  }

  Widget _loadMoreButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoadingMore ? null : _loadNextPage,
        child: const Text('더 불러오기'),
      ),
    );
  }

  Widget _resultHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택된 필터',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _filterChips()),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _hasMore ? '불러온 검색 결과 $count건' : '검색 결과 $count건',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LostSearchSortOption>(
                    value: selectedSort,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    items: LostSearchSortOption.values.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      );
                    }).toList(),
                    onChanged: (option) async {
                      if (option == null) {
                        return;
                      }

                      await _changeSort(option);
                    },
                  ),
                ),
              ),
            ],
          ),
          if (selectedSort == LostSearchSortOption.nearest &&
              _distanceReference != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _chooseDistanceReference,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '기준: ${_distanceReference!.label}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text(
                      '변경',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeSort(LostSearchSortOption option) async {
    if (option == LostSearchSortOption.nearest && _distanceReference == null) {
      final selected = await _chooseDistanceReference();
      if (!selected) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => selectedSort = option);
  }

  Future<bool> _chooseDistanceReference() async {
    final choice = await showModalBottomSheet<_DistanceReferenceChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '거리 기준 위치',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '검색 결과와의 거리를 계산할 기준을 선택해 주세요.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('현재 위치 사용'),
                subtitle: const Text('기기의 현재 위치를 기준으로 정렬합니다.'),
                onTap: () => Navigator.pop(
                  context,
                  _DistanceReferenceChoice.currentLocation,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('지도에서 위치 선택'),
                subtitle: const Text('원하는 장소를 직접 기준으로 지정합니다.'),
                onTap: () =>
                    Navigator.pop(context, _DistanceReferenceChoice.map),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) {
      return false;
    }

    final DistanceReference? reference;
    if (choice == _DistanceReferenceChoice.currentLocation) {
      reference = await _currentLocationReference();
    } else {
      reference = await Navigator.push<DistanceReference>(
        context,
        MaterialPageRoute(
          builder: (context) => DistanceReferenceMapPage(
            initialLocation: _distanceReference?.location,
          ),
        ),
      );
    }

    if (!mounted || reference == null) {
      return false;
    }

    setState(() {
      _distanceReference = reference;
      selectedSort = LostSearchSortOption.nearest;
    });
    return true;
  }

  Future<DistanceReference?> _currentLocationReference() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage('위치 서비스를 켠 후 다시 시도해 주세요.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationMessage('가까운순을 사용하려면 위치 권한이 필요합니다.');
        return null;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage('설정에서 위치 권한을 허용해 주세요.');
        return null;
      }

      final position = await getReliableCurrentPosition();
      return DistanceReference(
        location: LatLng(position.latitude, position.longitude),
        label: '현재 위치',
      );
    } catch (_) {
      _showLocationMessage('현재 위치를 불러오지 못했습니다. 다시 시도해 주세요.');
      return null;
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _filterChips() {
    final List<String> labels = [
      ...widget.filter.categories,
      if (widget.filter.keyword != null) widget.filter.keyword!,
      if (widget.filter.dateRange != null)
        '${_formatDate(widget.filter.dateRange!.start)} ~ ${_formatDate(widget.filter.dateRange!.end)}',
      if (widget.filter.region != null) widget.filter.region!,
      if (widget.filter.subregion != null) widget.filter.subregion!,
    ];

    if (labels.isEmpty) {
      return [_chip('전체')];
    }

    return labels.map(_chip).toList();
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _messageView({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadError = null;
    });

    try {
      Query<Map<String, dynamic>> query = _buildQuery().limit(_pageSize);
      final lastDocument = _lastDocument;
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get(
        const GetOptions(source: Source.server),
      );
      final List<LostItem> newItems = snapshot.docs
          .map(LostItem.fromDoc)
          .where(_matchesFilter)
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(newItems);
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
        _hasMore = snapshot.docs.length == _pageSize;
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = _searchErrorMessage(error);
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _searchErrorMessage(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
          return '서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
        case 'resource-exhausted':
          return '현재 검색 요청이 많습니다. 잠시 후 다시 시도해 주세요.';
        case 'permission-denied':
          return '검색 데이터에 접근할 권한이 없습니다. Firestore 보안 규칙을 확인해 주세요.';
        case 'failed-precondition':
          return '검색에 필요한 Firestore 색인이 준비되지 않았습니다.';
        case 'deadline-exceeded':
          return '서버 응답 시간이 초과되었습니다. 다시 시도해 주세요.';
      }
      return 'Firestore 검색 오류가 발생했습니다. (${error.code})';
    }
    return '검색 결과를 불러오는 중 오류가 발생했습니다. 다시 시도해 주세요.';
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      collectionName,
    );
    final LostSearchFilter filter = widget.filter;

    if (filter.categories.length == 1) {
      query = query.where('prdtClNmMg', isEqualTo: filter.categories.first);
    } else if (filter.categories.length > 1) {
      query = query.where('prdtClNmMg', whereIn: filter.categories);
    }

    if (filter.region != null) {
      query = query.where('sido', isEqualTo: filter.region);
    }

    if (filter.subregion != null) {
      final subregionField = filter.region == '세종특별자치시'
          ? 'eupmyeondong'
          : 'sigungu';
      query = query.where(subregionField, isEqualTo: filter.subregion);
    }

    if (filter.dateRange != null) {
      query = query
          .where(
            'fdYmd',
            isGreaterThanOrEqualTo: _queryDate(filter.dateRange!.start),
          )
          .where(
            'fdYmd',
            isLessThanOrEqualTo: _queryDate(filter.dateRange!.end),
          );
    }

    return query.orderBy('fdYmd', descending: true);
  }

  bool _matchesFilter(LostItem item) {
    final LostSearchFilter filter = widget.filter;

    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(item.prdtClNmMg)) {
      return false;
    }

    if (filter.region != null && !_matchesSido(item, filter.region!)) {
      return false;
    }

    if (filter.subregion != null &&
        !_matchesSubregion(item, filter.subregion!)) {
      return false;
    }

    if (filter.dateRange != null && item.fdYmd != null) {
      final DateTime foundDate = _dateOnly(item.fdYmd!);
      final DateTime start = _dateOnly(filter.dateRange!.start);
      final DateTime end = _dateOnly(filter.dateRange!.end);
      if (foundDate.isBefore(start) || foundDate.isAfter(end)) {
        return false;
      }
    }

    if (filter.dateRange != null && item.fdYmd == null) {
      return false;
    }

    if (filter.keyword != null && !_matchesDetailSearch(item)) {
      return false;
    }

    return true;
  }

  List<LostItem> _sortedItems(List<LostItem> items) {
    final List<LostItem> sorted = [...items];

    sorted.sort((a, b) {
      switch (selectedSort) {
        case LostSearchSortOption.similarity:
          return _similarityScore(b).compareTo(_similarityScore(a));
        case LostSearchSortOption.nearest:
          return _nullableDistanceCompare(_distanceTo(a), _distanceTo(b));
        case LostSearchSortOption.newest:
          return _nullableDateCompare(b.fdYmd, a.fdYmd);
        case LostSearchSortOption.oldest:
          return _nullableDateCompare(a.fdYmd, b.fdYmd);
      }
    });

    return sorted;
  }

  double? _distanceTo(LostItem item) {
    final reference = _distanceReference;
    final latitude = item.latitude;
    final longitude = item.longitude;
    if (reference == null || latitude == null || longitude == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      reference.location.latitude,
      reference.location.longitude,
      latitude,
      longitude,
    );
  }

  int _nullableDistanceCompare(double? a, double? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  int _similarityScore(LostItem item) {
    int score = 0;
    final List<String> keywords = _detailKeywords;
    final List<String> secondaryFields = [
      item.prdtClNmMg ?? '',
      item.prdtClNmMn ?? '',
      item.fndPlace ?? '',
      item.fndDescription ?? '',
      item.sido ?? '',
      item.sigungu ?? '',
      item.eupmyeondong ?? '',
    ].map(_normalizeSearchText).toList();

    for (final String keyword in keywords) {
      if (_normalizeSearchText(item.fdPrdtNm).contains(keyword)) {
        score += 5;
      }
      for (final String field in secondaryFields) {
        if (field.contains(keyword)) {
          score += 2;
        }
      }
    }

    if (item.prdtClNmMg != null &&
        widget.filter.categories.contains(item.prdtClNmMg)) {
      score += 3;
    }

    if (widget.filter.region != null &&
        _matchesSido(item, widget.filter.region!)) {
      score += 2;
    }

    return score;
  }

  bool _matchesDetailSearch(LostItem item) {
    final String searchableText = _normalizeSearchText(
      [
        item.fdPrdtNm,
        item.prdtClNmMg,
        item.prdtClNmMn,
        item.fndPlace,
        item.fndDescription,
        item.sido,
        item.sigungu,
        item.eupmyeondong,
      ].whereType<String>().join(' '),
    );

    return _detailKeywords.every(searchableText.contains);
  }

  List<String> get _detailKeywords {
    return (widget.filter.keyword ?? '')
        .toLowerCase()
        .split(_searchSeparator)
        .map(_normalizeSearchText)
        .where((keyword) => keyword.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _matchesSido(LostItem item, String sido) {
    return _normalizeSearchText(item.sido ?? '') == _normalizeSearchText(sido);
  }

  bool _matchesSubregion(LostItem item, String subregion) {
    final itemRegion = _normalizeSearchText(
      '${item.sigungu ?? ''} ${item.eupmyeondong ?? ''}',
    );
    return itemRegion.contains(_normalizeSearchText(subregion));
  }

  String _normalizeSearchText(String text) {
    return text.toLowerCase().replaceAll(_searchSeparator, '');
  }

  int _nullableDateCompare(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }

    return a.compareTo(b);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _queryDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 없음';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _LostItemCard extends StatelessWidget {
  const _LostItemCard({
    required this.item,
    required this.formatDate,
    required this.showDistance,
    required this.distanceMeters,
  });

  final LostItem item;
  final String Function(DateTime? date) formatDate;
  final bool showDistance;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.fdPrdtNm,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (item.prdtClNmMg != null)
                      _categoryBadge(item.prdtClNmMg!),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.calendar_today_outlined,
                  '습득일 ${formatDate(item.fdYmd)}',
                ),
                const SizedBox(height: 4),
                _infoRow(Icons.location_on_outlined, _locationText),
                if (showDistance) ...[
                  const SizedBox(height: 4),
                  _infoRow(
                    Icons.near_me_outlined,
                    distanceMeters == null
                        ? '거리 정보 없음'
                        : '기준 위치에서 ${_formatDistance(distanceMeters!)}',
                  ),
                ],
                if (item.fndDescription != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.fndDescription!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _locationText {
    final List<String> parts = [
      if (item.sido != null) item.sido!,
      if (item.sigungu != null) item.sigungu!,
      if (item.eupmyeondong != null) item.eupmyeondong!,
      if (item.fndPlace != null) item.fndPlace!,
    ];

    return parts.isEmpty ? '지역 정보 없음' : parts.join(' ');
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  Widget _thumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        color: const Color(0xFFEAF2FF),
        child: item.fdFilePathImg == null
            ? const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF2563EB),
                size: 32,
              )
            : Image.network(
                item.fdFilePathImg!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF9CA3AF),
                  );
                },
              ),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
