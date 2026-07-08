import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/lost_item.dart';
import '../models/lost_search_filter.dart';

enum LostSearchSortOption {
  similarity('유사도순'),
  distance('거리순'),
  newest('최신순'),
  oldest('오래된순');

  const LostSearchSortOption(this.label);

  final String label;
}

class LostSearchResultPage extends StatefulWidget {
  const LostSearchResultPage({
    super.key,
    required this.filter,
  });

  final LostSearchFilter filter;

  @override
  State<LostSearchResultPage> createState() => _LostSearchResultPageState();
}

class _LostSearchResultPageState extends State<LostSearchResultPage> {
  static const String collectionName = 'public_lost_items';
  static const Map<String, List<String>> regionKeywords = {
    '서울특별시': [
      '서울',
      '강남',
      '강동',
      '강북',
      '강서',
      '관악',
      '광진',
      '구로',
      '금천',
      '노원',
      '도봉',
      '동대문',
      '동작',
      '마포',
      '서대문',
      '서초',
      '성동',
      '성북',
      '송파',
      '양천',
      '영등포',
      '용산',
      '은평',
      '종로',
      '중구',
      '중랑',
      '잠실',
      '한강공원',
      '여의도',
      '홍대',
      '신촌',
      '명동',
      '건대',
      '뚝섬',
      '반포',
    ],
    '강원도': ['강원', '춘천', '원주', '강릉', '동해', '태백', '속초', '삼척'],
    '경기도': [
      '경기',
      '수원',
      '성남',
      '고양',
      '용인',
      '부천',
      '안산',
      '안양',
      '남양주',
      '화성',
      '평택',
      '의정부',
      '파주',
      '김포',
      '광명',
      '광주',
      '군포',
      '하남',
      '오산',
      '양주',
      '이천',
      '구리',
      '안성',
      '포천',
      '의왕',
      '양평',
      '여주',
      '동두천',
      '과천',
      '가평',
      '연천',
    ],
    '경상남도': ['경남', '창원', '진주', '통영', '사천', '김해', '밀양', '거제', '양산'],
    '경상북도': ['경북', '포항', '경주', '김천', '안동', '구미', '영주', '영천', '상주', '문경', '경산'],
    '광주광역시': ['광주'],
    '대구광역시': ['대구'],
    '대전광역시': ['대전'],
    '부산광역시': ['부산', '해운대', '서면', '광안리'],
    '울산광역시': ['울산'],
    '인천광역시': ['인천', '부평', '송도', '강화'],
    '전라남도': ['전남', '목포', '여수', '순천', '나주', '광양'],
    '전북특별자치도': ['전북', '전주', '군산', '익산', '정읍', '남원', '김제'],
    '충청남도': ['충남', '천안', '공주', '보령', '아산', '서산', '논산', '계룡', '당진'],
    '충청북도': ['충북', '청주', '충주', '제천'],
    '제주특별자치도': ['제주', '서귀포'],
    '세종특별자치시': ['세종'],
    '해외': ['해외'],
    '기타': ['기타'],
  };

  LostSearchSortOption selectedSort = LostSearchSortOption.similarity;
  late final Future<List<LostItem>> itemsFuture = _loadItems();

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
      body: FutureBuilder<List<LostItem>>(
        future: itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _messageView(
              icon: Icons.error_outline,
              title: '검색 결과를 불러오지 못했습니다',
              message: '${snapshot.error}',
            );
          }

          final List<LostItem> items = _sortedItems(snapshot.data ?? []);

          return Column(
            children: [
              _resultHeader(items.length),
              Expanded(
                child: items.isEmpty
                    ? _messageView(
                        icon: Icons.search_off_outlined,
                        title: '검색 결과가 없습니다',
                        message: '필터 조건을 줄이거나 다른 키워드로 검색해보세요.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _LostItemCard(
                            item: items[index],
                            formatDate: _formatDate,
                            formatDistance: _formatDistance,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _resultHeader(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '검색 결과 $count건',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              DropdownButton<LostSearchSortOption>(
                value: selectedSort,
                underline: const SizedBox.shrink(),
                items: LostSearchSortOption.values.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  );
                }).toList(),
                onChanged: (option) {
                  if (option == null) {
                    return;
                  }

                  setState(() {
                    selectedSort = option;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filterChips(),
          ),
        ],
      ),
    );
  }

  List<Widget> _filterChips() {
    final List<String> labels = [
      ...widget.filter.categories,
      if (widget.filter.keyword != null) widget.filter.keyword!,
      if (widget.filter.dateRange != null)
        '${_formatDate(widget.filter.dateRange!.start)} ~ ${_formatDate(widget.filter.dateRange!.end)}',
      if (widget.filter.region != null) widget.filter.region!,
      if (widget.filter.detailRegion != null) widget.filter.detailRegion!,
    ];

    if (labels.isEmpty) {
      return [
        _chip('전체'),
      ];
    }

    return labels.map(_chip).toList();
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFFEAF2FF),
      labelStyle: const TextStyle(
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _messageView({
    required IconData icon,
    required String title,
    required String message,
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
          ],
        ),
      ),
    );
  }

  Future<List<LostItem>> _loadItems() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection(collectionName).get();

    return snapshot.docs
        .map(LostItem.fromDoc)
        .where(_matchesFilter)
        .toList();
  }

  bool _matchesFilter(LostItem item) {
    final LostSearchFilter filter = widget.filter;

    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(item.category)) {
      return false;
    }

    if (filter.region != null && !_matchesRegion(item, filter.region!)) {
      return false;
    }

    if (filter.detailRegion != null) {
      final String target =
          '${item.region ?? ''} ${item.detailRegion ?? ''}'.toLowerCase();
      if (!target.contains(filter.detailRegion!.toLowerCase())) {
        return false;
      }
    }

    if (filter.dateRange != null && item.lostDate != null) {
      final DateTime lostDate = _dateOnly(item.lostDate!);
      final DateTime start = _dateOnly(filter.dateRange!.start);
      final DateTime end = _dateOnly(filter.dateRange!.end);
      if (lostDate.isBefore(start) || lostDate.isAfter(end)) {
        return false;
      }
    }

    if (filter.dateRange != null && item.lostDate == null) {
      return false;
    }

    if (filter.keyword != null && _similarityScore(item) == 0) {
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
        case LostSearchSortOption.distance:
          return _nullableDoubleCompare(a.distanceMeters, b.distanceMeters);
        case LostSearchSortOption.newest:
          return _nullableDateCompare(b.lostDate, a.lostDate);
        case LostSearchSortOption.oldest:
          return _nullableDateCompare(a.lostDate, b.lostDate);
      }
    });

    return sorted;
  }

  int _similarityScore(LostItem item) {
    int score = 0;
    final String keyword = widget.filter.keyword?.toLowerCase() ?? '';
    final List<String> fields = [
      item.title,
      item.category ?? '',
      item.region ?? '',
      item.detailRegion ?? '',
      item.description ?? '',
    ].map((value) => value.toLowerCase()).toList();

    if (keyword.isNotEmpty) {
      if (item.title.toLowerCase().contains(keyword)) {
        score += 5;
      }
      for (final String field in fields.skip(1)) {
        if (field.contains(keyword)) {
          score += 2;
        }
      }
    }

    if (item.category != null &&
        widget.filter.categories.contains(item.category)) {
      score += 3;
    }

    if (widget.filter.region != null &&
        _matchesRegion(item, widget.filter.region!)) {
      score += 2;
    }

    return score;
  }

  bool _matchesRegion(LostItem item, String region) {
    final String locationText = _normalizeText(
      '${item.region ?? ''} ${item.detailRegion ?? ''}',
    );
    final List<String> keywords = regionKeywords[region] ?? [region];

    return keywords.any((keyword) {
      return locationText.contains(_normalizeText(keyword));
    });
  }

  String _normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
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

  int _nullableDoubleCompare(double? a, double? b) {
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

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 없음';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return '거리 정보 없음';
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }

    return '${meters.round()}m';
  }
}

class _LostItemCard extends StatelessWidget {
  const _LostItemCard({
    required this.item,
    required this.formatDate,
    required this.formatDistance,
  });

  final LostItem item;
  final String Function(DateTime? date) formatDate;
  final String Function(double? meters) formatDistance;

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
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    if (item.category != null) _categoryBadge(item.category!),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.calendar_today_outlined,
                  '분실일 ${formatDate(item.lostDate)}',
                ),
                const SizedBox(height: 4),
                _infoRow(
                  Icons.location_on_outlined,
                  _locationText,
                ),
                const SizedBox(height: 4),
                _infoRow(
                  Icons.near_me_outlined,
                  formatDistance(item.distanceMeters),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.description!,
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
      if (item.region != null) item.region!,
      if (item.detailRegion != null) item.detailRegion!,
    ];

    return parts.isEmpty ? '지역 정보 없음' : parts.join(' ');
  }

  Widget _thumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        color: const Color(0xFFEAF2FF),
        child: item.imageUrl == null
            ? const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF2563EB),
                size: 32,
              )
            : Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
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
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
