import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../lost_models/lost_search_filter.dart';
import '../lost_models/korean_administrative_regions.dart';
import '../utils/current_position.dart';
import '../widgets/date_range_bottom_sheet.dart';
import 'lost_search_result_page.dart';

class DetectedSearchRegion {
  const DetectedSearchRegion({required this.region, this.subregion});

  final String region;
  final String? subregion;
}

typedef SearchRegionDetector =
    Future<DetectedSearchRegion?> Function({required bool requestPermission});

class LostSearchPage extends StatefulWidget {
  const LostSearchPage({
    super.key,
    this.autoDetectLocation = true,
    this.regionDetector,
    this.initialDetectedRegion,
  });

  final bool autoDetectLocation;
  final SearchRegionDetector? regionDetector;
  final DetectedSearchRegion? initialDetectedRegion;

  @override
  State<LostSearchPage> createState() => _LostSearchPageState();
}

class _LostSearchPageState extends State<LostSearchPage> {
  final TextEditingController keywordController = TextEditingController();
  final ExpansibleController regionAccordionController = ExpansibleController();
  final ExpansibleController subregionAccordionController =
      ExpansibleController();

  final Set<String> selectedCategories = {};
  String selectedRegion = '선택';
  String? selectedSubregion;
  late DateTimeRange selectedDateRange;
  bool _isLocating = false;
  bool _isUsingCurrentLocation = false;
  String? _locationMessage;
  int _locationRequestId = 0;

  final List<String> categories = [
    '가방',
    '귀금속',
    '도서용품',
    '서류',
    '산업용품',
    '쇼핑백',
    '스포츠용품',
    '악기',
    '유가증권',
    '의류',
    '자동차',
    '전자기기',
    '지갑',
    '증명서',
    '컴퓨터',
    '카드',
    '현금',
    '휴대폰',
    '기타물품',
  ];

  final List<String> regions = [
    '서울특별시',
    '강원도',
    '경기도',
    '경상남도',
    '경상북도',
    '광주광역시',
    '대구광역시',
    '대전광역시',
    '부산광역시',
    '울산광역시',
    '인천광역시',
    '전라남도',
    '전북특별자치도',
    '충청남도',
    '충청북도',
    '제주특별자치도',
    '세종특별자치시',
    '해외',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    selectedDateRange = _recentThreeDays();
    final initialRegion = widget.initialDetectedRegion;
    if (initialRegion != null) {
      selectedRegion = initialRegion.region;
      selectedSubregion = initialRegion.subregion;
      _isUsingCurrentLocation = true;
    } else if (widget.autoDetectLocation && !kIsWeb) {
      _setRegionFromCurrentLocation(requestPermission: false);
    }
  }

  @override
  void dispose() {
    keywordController.dispose();
    super.dispose();
  }

  Future<void> pickDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? pickedRange =
        await showModalBottomSheet<DateTimeRange>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return DateRangeBottomSheet(
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year, now.month, now.day),
              initialDateRange: selectedDateRange,
            );
          },
        );

    if (pickedRange != null) {
      setState(() {
        selectedDateRange = pickedRange;
      });
    }
  }

  DateTimeRange _recentThreeDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(
      start: today.subtract(const Duration(days: 2)),
      end: today,
    );
  }

  bool get _isRecentThreeDays {
    final recent = _recentThreeDays();
    return selectedDateRange.start == recent.start &&
        selectedDateRange.end == recent.end;
  }

  Future<void> _setRegionFromCurrentLocation({
    required bool requestPermission,
  }) async {
    if (_isLocating) {
      return;
    }

    final requestId = ++_locationRequestId;
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });

    try {
      final customDetector = widget.regionDetector;
      if (customDetector != null) {
        try {
          final detected = await customDetector(
            requestPermission: requestPermission,
          );
          if (detected != null) {
            _applyDetectedRegion(requestId, detected.region, detected.subregion);
            return;
          }
        } catch (_) {
          // 메인 지도의 주소 변환이 실패하면 아래의 기기 위치 조회를 사용한다.
        }
      }

      if (kIsWeb) {
        _finishLocationLookup(
          requestId,
          '웹에서는 현재 위치의 지역명 자동 변환을 지원하지 않아요. 지역을 직접 선택해 주세요.',
        );
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 5),
      )) {
        _finishLocationLookup(requestId, '위치 서비스를 켜면 현재 지역을 자동으로 설정할 수 있어요.');
        return;
      }

      var permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 5),
      );
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 30),
        );
      }

      if (permission == LocationPermission.denied) {
        _finishLocationLookup(requestId, '현재 위치로 지역 설정을 하려면 위치 권한을 허용해 주세요.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _finishLocationLookup(requestId, '설정에서 위치 권한을 허용한 뒤 다시 시도해 주세요.');
        return;
      }

      final position = await getReliableCurrentPosition();

      final placemarks = await Geocoding(locale: const Locale('ko', 'KR'))
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) {
        _finishLocationLookup(requestId, '현재 위치의 지역명을 확인하지 못했어요.');
        return;
      }

      final placemark = placemarks.first;
      final region = _findSupportedRegion(placemark);
      if (region == null) {
        _finishLocationLookup(requestId, '현재 위치는 지역 필터에서 찾지 못했어요.');
        return;
      }

      final subregion = _findSupportedSubregion(placemark, region);
      _applyDetectedRegion(requestId, region, subregion);
    } catch (_) {
      _finishLocationLookup(requestId, '현재 위치를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _applyDetectedRegion(int requestId, String region, String? subregion) {
    if (!_isActiveLocationRequest(requestId)) {
      return;
    }

    setState(() {
      selectedRegion = region;
      selectedSubregion = subregion;
      _isLocating = false;
      _isUsingCurrentLocation = true;
      _locationMessage = subregion == null
          ? '현재 위치 기준으로 $region을 선택했어요.'
          : '현재 위치 기준으로 $region $subregion을 선택했어요.';
    });
  }

  void _finishLocationLookup(int requestId, String message) {
    if (!_isActiveLocationRequest(requestId)) {
      return;
    }
    setState(() {
      _isLocating = false;
      _isUsingCurrentLocation = false;
      _locationMessage = message;
    });
  }

  bool _isActiveLocationRequest(int requestId) {
    return mounted && requestId == _locationRequestId;
  }

  void _cancelPendingLocationLookup() {
    _locationRequestId++;
    _isLocating = false;
    _isUsingCurrentLocation = false;
    _locationMessage = null;
  }

  String? _findSupportedRegion(Placemark placemark) {
    final candidates = _placemarkParts(placemark);
    const aliases = {'강원특별자치도': '강원도', '전라북도': '전북특별자치도'};

    for (final candidate in candidates) {
      final normalized = aliases[candidate] ?? candidate;
      for (final region in regions) {
        if (normalized == region || normalized.contains(region)) {
          return region;
        }
      }
    }
    return null;
  }

  String? _findSupportedSubregion(Placemark placemark, String region) {
    final supported = koreanSubregions[region] ?? const <String>[];
    final candidates = _placemarkParts(placemark);

    for (final candidate in candidates) {
      for (final subregion in supported) {
        if (candidate == subregion || candidate.contains(subregion)) {
          return subregion;
        }
      }
    }
    return null;
  }

  List<String> _placemarkParts(Placemark placemark) {
    return [
          placemark.administrativeArea,
          placemark.subAdministrativeArea,
          placemark.locality,
          placemark.subLocality,
          placemark.name,
        ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  void searchLostItems() {
    final String keyword = keywordController.text.trim();

    final LostSearchFilter searchFilter = LostSearchFilter(
      categories: selectedCategories.toList(),
      keyword: keyword.isEmpty ? null : keyword,
      dateRange: selectedDateRange,
      region: selectedRegion == '선택' ? null : selectedRegion,
      subregion: selectedSubregion,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LostSearchResultPage(filter: searchFilter),
      ),
    );
  }

  void resetFilters() {
    setState(() {
      _cancelPendingLocationLookup();
      selectedCategories.clear();
      selectedRegion = '선택';
      selectedSubregion = null;
      selectedDateRange = _recentThreeDays();
      keywordController.clear();
    });
    _setRegionFromCurrentLocation(requestPermission: false);
  }

  String get dateRangeText {
    final DateTime start = selectedDateRange.start;
    final DateTime end = selectedDateRange.end;

    return '${_formatDate(start)}  ~  ${_formatDate(end)}';
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<Widget> buildAppliedFilterChips() {
    final List<Widget> chips = [];
    final String keyword = keywordController.text.trim();

    for (final String category in selectedCategories) {
      chips.add(_filterChip(category));
    }

    if (keyword.isNotEmpty) {
      chips.add(_filterChip(keyword));
    }

    chips.add(
      _filterChip(
        _isRecentThreeDays ? '$dateRangeText · 최근 3일' : dateRangeText,
      ),
    );

    if (selectedRegion != '선택') {
      chips.add(_filterChip(selectedRegion));
    }

    if (selectedSubregion != null) {
      chips.add(_filterChip(selectedSubregion!));
    }

    return chips;
  }

  Widget _filterChip(String text) {
    return Chip(
      label: Text(text),
      backgroundColor: const Color(0xFFEAF2FF),
      labelStyle: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> appliedFilters = buildAppliedFilterChips();
    final List<String> subregions =
        koreanSubregions[selectedRegion] ?? const [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '분실물 검색 필터',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _optionAccordion(
                      icon: Icons.category_outlined,
                      title: '물품 분류',
                      hintText: '물품 분류를 선택하세요',
                      selectedValues: selectedCategories,
                      options: categories,
                      onSelected: (value) {
                        setState(() {
                          if (selectedCategories.contains(value)) {
                            selectedCategories.remove(value);
                          } else {
                            selectedCategories.add(value);
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle(Icons.calendar_month_outlined, '습득일자'),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dateRangeText,
                                style: TextStyle(
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _optionAccordion(
                      controller: regionAccordionController,
                      icon: Icons.location_on_outlined,
                      title: '지역',
                      headerAccessory: _currentLocationAction(),
                      footerAccessory: _currentLocationFeedback(),
                      hintText: '지역을 선택하세요',
                      selectedValues: selectedRegion == '선택'
                          ? const <String>{}
                          : {selectedRegion},
                      options: regions,
                      onSelected: (value) {
                        setState(() {
                          _cancelPendingLocationLookup();
                          selectedRegion = selectedRegion == value
                              ? '선택'
                              : value;
                          selectedSubregion = null;
                        });
                        regionAccordionController.collapse();
                      },
                    ),

                    if (subregions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _optionAccordion(
                        controller: subregionAccordionController,
                        icon: Icons.account_tree_outlined,
                        title: selectedRegion == '세종특별자치시' ? '읍·면·동' : '시·군·구',
                        hintText: selectedRegion == '세종특별자치시'
                            ? '읍·면·동을 선택하세요'
                            : '시·군·구를 선택하세요',
                        selectedValues: selectedSubregion == null
                            ? const <String>{}
                            : {selectedSubregion!},
                        options: subregions,
                        onSelected: (value) {
                          setState(() {
                            _cancelPendingLocationLookup();
                            selectedSubregion = selectedSubregion == value
                                ? null
                                : value;
                          });
                          subregionAccordionController.collapse();
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    _sectionTitle(Icons.search, '상세 검색'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: keywordController,
                      decoration: InputDecoration(
                        hintText: '물품명, 장소, 특징 등을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    if (appliedFilters.isNotEmpty) ...[
                      const Text(
                        '적용된 필터',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: appliedFilters),
                    ],
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: searchLostItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '검색하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: resetFilters,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('초기화'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentLocationAction() {
    return TextButton.icon(
      onPressed: _isLocating
          ? null
          : () => _setRegionFromCurrentLocation(requestPermission: true),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: _isLocating
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location, size: 15),
      label: Text(
        _isLocating ? '현재 위치 확인 중' : '현재 위치로 설정',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget? _currentLocationFeedback() {
    final message = _locationMessage;
    if (message == null) {
      return null;
    }

    final color = _isUsingCurrentLocation
        ? const Color(0xFF2563EB)
        : const Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _isUsingCurrentLocation
              ? Icons.check_circle_outline
              : Icons.info_outline,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _optionAccordion({
    ExpansibleController? controller,
    required IconData icon,
    required String title,
    Widget? headerAccessory,
    Widget? footerAccessory,
    required String hintText,
    required Set<String> selectedValues,
    required List<String> options,
    required void Function(String value) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerAccessory == null)
          _sectionTitle(icon, title)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _sectionTitle(icon, title),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: headerAccessory,
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            controller: controller,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              selectedValues.isEmpty ? hintText : selectedValues.join(', '),
              style: TextStyle(
                color: selectedValues.isEmpty
                    ? Colors.grey
                    : const Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final bool isSelected = selectedValues.contains(option);

                    return ChoiceChip(
                      label: Text(option),
                      selected: isSelected,
                      selectedColor: const Color(0xFFDBEAFE),
                      backgroundColor: const Color(0xFFF3F4F6),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFD1D5DB),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (_) {
                        onSelected(option);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        if (footerAccessory != null) ...[
          const SizedBox(height: 7),
          footerAccessory,
        ],
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF374151)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
