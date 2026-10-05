import 'package:flutter_test/flutter_test.dart';
import 'package:map_test/models/found_item_registration.dart';
import 'package:map_test/repositories/found_item_repository.dart';
import 'package:map_test/utils/geohash_query.dart';

void main() {ㅁ
  FoundItemRegistration registration({
    String eupmyeondong = '등촌동',
    double? latitude = 37.559,
    double? longitude = 126.801,
  }) {
    return FoundItemRegistration(
      itemName: '검정 가방',
      category: '가방',
      foundAt: DateTime(2026, 10, 5),
      foundPlace: '김포국제공항 · 서울 강서구 하늘길 38',
      description: '',
      contact: '010-1234-5678',
      password: '1234',
      latitude: latitude,
      longitude: longitude,
      sido: '서울특별시',
      sigungu: '강서구',
      eupmyeondong: eupmyeondong,
    );
  }

  test(
    'Firestore fndPlace stores administrative names, not the selected address',
    () {
      final item = registration();
      final data = buildFoundItemFirestoreData(
        atcId: 'S2026100512345678',
        item: item,
        imageUrl: '',
      );

      expect(data['fndPlace'], '서울특별시 강서구 등촌동');
      expect(data['fndPlace'], isNot(contains('김포국제공항')));
      expect(data['fndPlace'], isNot(contains('하늘길')));
      expect(data['sido'], '서울특별시');
      expect(data['sigungu'], '강서구');
      expect(data['eupmyeondong'], '등촌동');
      expect(data['latitude'], isA<double>());
      expect(data['latitude'], item.latitude);
      expect(data['longitude'], isA<double>());
      expect(data['longitude'], item.longitude);
      expect(
        data['geohash'],
        encodeGeohash(item.latitude!, item.longitude!, precision: 8),
      );
    },
  );

  test('unresolved eupmyeondong is omitted rather than fabricated', () {
    final data = buildFoundItemFirestoreData(
      atcId: 'S2026100512345678',
      item: registration(eupmyeondong: ''),
      imageUrl: '',
    );

    expect(data['fndPlace'], '서울특별시 강서구');
    expect(data['eupmyeondong'], '');
  });

  test('missing coordinates remain nullable and produce no geohash', () {
    final data = buildFoundItemFirestoreData(
      atcId: 'S2026100512345678',
      item: registration(latitude: null, longitude: null),
      imageUrl: '',
    );

    expect(data['latitude'], isNull);
    expect(data['longitude'], isNull);
    expect(data['geohash'], '');
  });
}
