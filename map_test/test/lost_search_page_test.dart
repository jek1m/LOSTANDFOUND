import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_test/pages/lost_search_page.dart';

void main() {
  testWidgets('진입하면 오늘을 포함한 최근 3일이 선택된다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 2));

    String format(DateTime date) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '${date.year}-$month-$day';
    }

    await tester.pumpWidget(
      const MaterialApp(home: LostSearchPage(autoDetectLocation: false)),
    );

    expect(find.text('${format(start)}  ~  ${format(today)}'), findsOneWidget);
    expect(find.textContaining('최근 3일'), findsOneWidget);
  });

  testWidgets('상위 지역을 선택하면 하위 행정구역 선택 바가 표시된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LostSearchPage(autoDetectLocation: false)),
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

  testWidgets('수동 지역 선택 후 늦게 끝난 자동 위치 결과는 적용하지 않는다', (tester) async {
    final detectorResult = Completer<DetectedSearchRegion?>();

    await tester.pumpWidget(
      MaterialApp(
        home: LostSearchPage(
          regionDetector: ({required requestPermission}) =>
              detectorResult.future,
        ),
      ),
    );

    await tester.tap(find.text('지역을 선택하세요'));
    await tester.pump(const Duration(milliseconds: 500));
    final busanChip = find.widgetWithText(ChoiceChip, '부산광역시');
    await tester.ensureVisible(busanChip);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(busanChip);
    await tester.pump(const Duration(milliseconds: 500));

    detectorResult.complete(
      const DetectedSearchRegion(region: '서울특별시', subregion: '강남구'),
    );
    await tester.pump();

    final appliedChips = find.byType(Chip);
    expect(
      find.descendant(of: appliedChips, matching: find.text('부산광역시')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: appliedChips, matching: find.text('서울특별시')),
      findsNothing,
    );
  });
}
