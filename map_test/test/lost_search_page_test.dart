import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_test/pages/lost_search_page.dart';

void main() {
  testWidgets('상위 지역을 선택하면 하위 행정구역 선택 바가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LostSearchPage()),
    );

    final regionSelector = find.text('지역을 선택하세요');
    await tester.ensureVisible(regionSelector);
    await tester.tap(regionSelector);
    await tester.pumpAndSettle();

    await tester.tap(find.text('서울특별시'));
    await tester.pumpAndSettle();

    final subregionSelector = find.text('시·군·구를 선택하세요');
    expect(subregionSelector, findsOneWidget);

    await tester.ensureVisible(subregionSelector);
    await tester.tap(subregionSelector);
    await tester.pumpAndSettle();

    expect(find.text('금천구'), findsOneWidget);
    expect(find.text('관악구'), findsOneWidget);
    expect(find.text('영등포구'), findsOneWidget);
  });
}
