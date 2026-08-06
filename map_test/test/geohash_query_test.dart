import 'package:flutter_test/flutter_test.dart';
import 'package:map_test/utils/geohash_query.dart';

void main() {
  test('서울시청 좌표를 표준 geohash로 인코딩한다', () {
    expect(
      encodeGeohash(37.5665, 126.9780, precision: 8),
      'wydm9qy8',
    );
  });

  test('반경 검색 범위는 중복되지 않고 유효한 순서를 가진다', () {
    final ranges = geohashQueryRanges(
      latitude: 37.5665,
      longitude: 126.9780,
      radiusMeters: 5000,
    );

    expect(ranges, isNotEmpty);
    expect(ranges.length, lessThanOrEqualTo(9));
    expect(ranges.toSet().length, ranges.length);
    for (final range in ranges) {
      expect(range.start.compareTo(range.end), lessThan(0));
    }
  });
}
