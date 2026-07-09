import 'package:cloud_firestore/cloud_firestore.dart';

class LostItem {
  const LostItem({
    required this.id,
    required this.title,
    required this.category,
    required this.region,
    required this.detailRegion,
    required this.description,
    required this.lostDate,
    required this.createdAt,
    required this.imageUrl,
    required this.distanceMeters,
  });

  final String id;
  final String title;
  final String? category;
  final String? region;
  final String? detailRegion;
  final String? description;
  final DateTime? lostDate;
  final DateTime? createdAt;
  final String? imageUrl;
  final double? distanceMeters;

  factory LostItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? {};

    return LostItem(
      id: doc.id,
      title: _string(data, ['lstPrdtNm', 'title', 'name', 'itemName', 'lostName']) ??
          '이름 없음',
      category: _string(data, [
        'majorCategory',
        'minorCategory',
        'prdtClNm',
        'category',
        'itemCategory',
      ]),
      region: _string(data, ['region', 'city', 'area', 'placeQuery']),
      detailRegion: _string(data, ['lstPlace', 'detailRegion', 'address', 'place']),
      description: _string(data, ['prdtClNm', 'description', 'memo', 'content']),
      lostDate: _date(data, ['lstYmd', 'lostDate', 'date']),
      createdAt: _date(data, ['createdAt', 'registeredAt', 'updatedAt']),
      imageUrl: _string(data, ['imageUrl', 'photoUrl', 'thumbnailUrl']),
      distanceMeters: _double(data, ['distanceMeters', 'distance']),
    );
  }

  static String? _string(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static DateTime? _date(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
    }

    return null;
  }

  static double? _double(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
    }

    return null;
  }
}
