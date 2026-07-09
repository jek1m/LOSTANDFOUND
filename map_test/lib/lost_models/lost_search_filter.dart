import 'package:flutter/material.dart';

class LostSearchFilter {
  const LostSearchFilter({
    required this.categories,
    required this.keyword,
    required this.dateRange,
    required this.region,
    required this.detailRegion,
  });

  final List<String> categories;
  final String? keyword;
  final DateTimeRange? dateRange;
  final String? region;
  final String? detailRegion;

  bool get hasFilter {
    return categories.isNotEmpty ||
        keyword != null ||
        dateRange != null ||
        region != null ||
        detailRegion != null;
  }
}
