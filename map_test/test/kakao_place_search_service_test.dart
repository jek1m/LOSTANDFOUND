import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_test/services/kakao_place_search_service.dart';

void main() {
  final place = {
    'place_name': '김포국제공항',
    'road_address_name': '서울 강서구 하늘길 38',
    'x': '126.801',
    'y': '37.559',
  };

  for (final doubleEncoded in [false, true]) {
    test('decodes mobile response (double encoded: $doubleEncoded)', () async {
      final service = KakaoPlaceSearchService.withJavaScript(
        run: (_) async {},
        evaluate: (script) async {
          if (script.contains('foundPlaceSearchReady')) return true;
          final result = jsonEncode({
            'status': 'OK',
            'places': [place],
            'hasNext': true,
          });
          return doubleEncoded ? jsonEncode(result) : result;
        },
      );
      final result = await service.search('김포공항');
      expect(result.places.single.placeName, '김포국제공항');
      expect(result.places.single.roadAddressName, '서울 강서구 하늘길 38');
      expect(result.places.single.x, '126.801');
      expect(result.places.single.y, '37.559');
      expect(result.hasNext, isTrue);
    });
  }

  test('empty results complete normally', () async {
    final service = KakaoPlaceSearchService.withJavaScript(
      run: (_) async {},
      evaluate: (script) async {
        if (script.contains('foundPlaceSearchReady')) return true;
        return jsonEncode({
          'status': 'ZERO_RESULT',
          'places': [],
          'hasNext': false,
        });
      },
    );
    final result = await service.search('없는 장소');
    expect(result.places, isEmpty);
    expect(result.hasNext, isFalse);
  });

  test('API errors are reported instead of treated as empty results', () async {
    final service = KakaoPlaceSearchService.withJavaScript(
      run: (_) async {},
      evaluate: (script) async {
        if (script.contains('foundPlaceSearchReady')) return true;
        return jsonEncode({'status': 'ERROR'});
      },
    );
    await expectLater(service.search('공항'), throwsStateError);
  });

  test('quotes are escaped and pages use separate requests', () async {
    final scripts = <String>[];
    final service = KakaoPlaceSearchService.withJavaScript(
      run: (script) async => scripts.add(script),
      evaluate: (script) async {
        if (script.contains('foundPlaceSearchReady')) return true;
        return jsonEncode({
          'status': 'OK',
          'places': [place],
          'hasNext': false,
        });
      },
    );
    const keyword = 'O\'Brien "빌딩"\\입구';
    await service.initialize();
    await service.search(keyword);
    await service.search(keyword, page: 2);
    expect(scripts[1], contains(jsonEncode(keyword)));
    expect(scripts[1], contains('foundPlaceSearchResults[1]'));
    expect(scripts[3], contains('foundPlaceSearchResults[2]'));
    expect(scripts[3], contains('page: 2'));
    expect(scripts[4], contains('delete window.foundPlaceSearchResults[2]'));
    service.dispose();
    await expectLater(service.search(keyword), throwsStateError);
  });
}
