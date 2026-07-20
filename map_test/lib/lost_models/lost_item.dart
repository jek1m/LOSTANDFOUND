import 'package:cloud_firestore/cloud_firestore.dart';

class LostItem {
  const LostItem({
    required this.atcId,
    required this.fdPrdtNm,
    required this.prdtClNmMg,
    required this.prdtClNmMn,
    required this.fndPlace,
    required this.fndDescription,
    required this.fdYmd,
    required this.fdFilePathImg,
    required this.tel,
    required this.polUse,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
  });

  final String atcId;
  final String fdPrdtNm;
  final String? prdtClNmMg;
  final String? prdtClNmMn;
  final String? fndPlace;
  final String? fndDescription;
  final DateTime? fdYmd;
  final String? fdFilePathImg;
  final String? tel;
  final String? polUse;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final String? sido;
  final String? sigungu;
  final String? eupmyeondong;

  factory LostItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? {};

    return LostItem(
      atcId: _string(data['atcId']) ?? doc.id,
      fdPrdtNm: _string(data['fdPrdtNm']) ?? '이름 없음',
      prdtClNmMg: _string(data['prdtClNmMg']),
      prdtClNmMn: _string(data['prdtClNmMn']),
      fndPlace: _string(data['fndPlace']),
      fndDescription: _string(data['fndDescription']),
      fdYmd: _date(data['fdYmd']),
      fdFilePathImg: _string(data['fdFilePathImg']),
      tel: _string(data['tel']),
      polUse: _string(data['polUse']),
      latitude: _double(data['latitude']),
      longitude: _double(data['longitude']),
      geohash: _string(data['geohash']),
      sido: _string(data['sido']),
      sigungu: _string(data['sigungu']),
      eupmyeondong: _string(data['eupmyeondong']),
    );
  }

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final String text = value.trim();
      final DateTime? parsed = DateTime.tryParse(text);
      if (parsed != null) {
        return parsed;
      }

      if (RegExp(r'^\d{8}$').hasMatch(text)) {
        return DateTime.tryParse(
          '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)}',
        );
      }
    }

    return null;
  }

  static double? _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}
