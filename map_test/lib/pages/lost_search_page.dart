import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController keywordController = TextEditingController();
  final TextEditingController detailRegionController = TextEditingController();

  String? selectedCategory;
  String selectedRegion = '선택';
  DateTimeRange? selectedDateRange;

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
  void dispose() {
    keywordController.dispose();
    detailRegionController.dispose();
    super.dispose();
  }

  Future<void> pickDateRange() async {
    final DateTime now = DateTime.now();

    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: selectedDateRange,
      helpText: '분실 일자 선택',
      cancelText: '취소',
      confirmText: '선택',
      saveText: '적용',
    );

    if (pickedRange != null) {
      setState(() {
        selectedDateRange = pickedRange;
      });
    }
  }

  void searchLostItems() {
    final String keyword = keywordController.text.trim();
    final String detailRegion = detailRegionController.text.trim();

    final Map<String, dynamic> searchFilter = {
      'category': selectedCategory,
      'keyword': keyword.isEmpty ? null : keyword,
      'startDate': selectedDateRange?.start,
      'endDate': selectedDateRange?.end,
      'region': selectedRegion == '선택' ? null : selectedRegion,
      'detailRegion': detailRegion.isEmpty ? null : detailRegion,
    };

    debugPrint('검색 필터: $searchFilter');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('검색 조건이 저장되었습니다. '),
      ),
    );
  }

  void resetFilters() {
    setState(() {
      selectedCategory = null;
      selectedRegion = '선택';
      selectedDateRange = null;
      keywordController.clear();
      detailRegionController.clear();
    });
  }

  String get dateRangeText {
    if (selectedDateRange == null) {
      return '연도-월-일  ~  연도-월-일';
    }

    final DateTime start = selectedDateRange!.start;
    final DateTime end = selectedDateRange!.end;

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
    final String detailRegion = detailRegionController.text.trim();

    if (selectedCategory != null) {
      chips.add(_filterChip(selectedCategory!));
    }

    if (keyword.isNotEmpty) {
      chips.add(_filterChip(keyword));
    }

    if (selectedDateRange != null) {
      chips.add(_filterChip(dateRangeText));
    }

    if (selectedRegion != '선택') {
      chips.add(
        _filterChip(detailRegion.isEmpty ? selectedRegion : '$selectedRegion $detailRegion'),
      );
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
                      selectedValue: selectedCategory,
                      options: categories,
                      onSelected: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle(Icons.search, '분실물명'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: keywordController,
                      decoration: InputDecoration(
                        hintText: '물품 이름을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    _sectionTitle(Icons.calendar_month_outlined, '분실일자'),

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
                                  color: selectedDateRange == null
                                      ? Colors.grey
                                      : const Color(0xFF111827),
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
                      icon: Icons.location_on_outlined,
                      title: '지역',
                      hintText: '지역을 선택하세요',
                      selectedValue: selectedRegion == '선택' ? null : selectedRegion,
                      options: regions,
                      onSelected: (value) {
                        setState(() {
                          selectedRegion = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: detailRegionController,
                      decoration: InputDecoration(
                        hintText: '상세 지역을 입력하세요. 예: 고양시, 강남구',
                        helperText: '선택하지 않으면 전체 검색',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: appliedFilters,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
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

  Widget _optionAccordion({
    required IconData icon,
    required String title,
    required String hintText,
    required String? selectedValue,
    required List<String> options,
    required void Function(String value) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(icon, title),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            title: Text(
              selectedValue ?? hintText,
              style: TextStyle(
                color: selectedValue == null
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
                    final bool isSelected = selectedValue == option;

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
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
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