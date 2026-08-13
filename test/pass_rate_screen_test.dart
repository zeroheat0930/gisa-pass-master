import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/data/pass_rate_data.dart';
import 'package:gisa_pass_master/screens/pass_rate_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PassRateScreen()));
    await tester.pump();
  }

  testWidgets('실기가 먼저 보인다 (이 앱은 실기 대비용이다)', (tester) async {
    await pump(tester);

    final practicalAvg = PassRateData.roundAverage(
      ExamKind.practical,
    ).toStringAsFixed(1);
    expect(find.text(practicalAvg), findsOneWidget);
    expect(find.text('실기 회차 평균 합격률'), findsOneWidget);
  });

  testWidgets('필기로 바꾸면 숫자가 필기 값으로 바뀐다', (tester) async {
    await pump(tester);

    await tester.tap(find.text('필기'));
    await tester.pumpAndSettle();

    final writtenAvg = PassRateData.roundAverage(
      ExamKind.written,
    ).toStringAsFixed(1);
    expect(find.text('필기 회차 평균 합격률'), findsOneWidget);
    expect(find.text(writtenAvg), findsOneWidget);
  });

  testWidgets('최고·최저 회차가 실제 데이터와 맞게 표시된다', (tester) async {
    await pump(tester);

    final high = PassRateData.highest(ExamKind.practical);
    final low = PassRateData.lowest(ExamKind.practical);

    // 실기 최고는 2021년 1회(39.49%), 최저는 2020년 1회(5.34%) 다.
    expect(high.label, '2021년 1회');
    expect(low.label, '2020년 1회');
    expect(find.text('${high.rate.toStringAsFixed(1)}%'), findsWidgets);
    expect(find.text('${low.rate.toStringAsFixed(1)}%'), findsWidgets);
  });

  testWidgets('표에 모든 회차가 들어 있다', (tester) async {
    await pump(tester);

    // ListView 라 표가 화면 밖에 있을 수 있다. 위젯 트리에 있는지로 본다.
    final rows = PassRateData.of(ExamKind.practical);
    expect(find.byType(Table), findsWidgets);
    expect(
      find.text(rows.first.label, skipOffstage: false),
      findsWidgets,
      reason: '첫 회차가 표에 있어야 한다',
    );
  });

  testWidgets('좁은 화면에서도 오버플로가 없다', (tester) async {
    for (final width in [320.0, 390.0]) {
      await pump(tester, width: width);
      expect(tester.takeException(), isNull, reason: 'W$width 에서 넘쳤다');

      await tester.tap(find.text('필기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'W$width 필기 탭에서 넘쳤다');
    }
  });

  testWidgets('모든 회차가 화면 폭 안에 들어온다 (스크롤 뒤로 숨지 않는다)', (tester) async {
    await pump(tester, width: 320);

    // 예전엔 고정 폭 막대 + 가로 스크롤이라 21개 중 11개만 보였다.
    // 이 차트의 목적이 전체 흐름을 한눈에 보는 것이라 숨으면 의미가 없다.
    final rows = PassRateData.of(ExamKind.practical);

    final bars = tester
        .widgetList<Container>(find.byType(Container, skipOffstage: false))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color == const Color(0xFF569CD6),
        )
        .toList();
    expect(bars, hasLength(rows.length), reason: '막대 수가 회차 수와 달라졌다');

    // 차트 안에 가로 스크롤이 남아 있으면 다시 숨는다.
    final chartScrolls = tester
        .widgetList<SingleChildScrollView>(
          find.byType(SingleChildScrollView, skipOffstage: false),
        )
        .where((s) => s.scrollDirection == Axis.horizontal);
    expect(chartScrolls, isEmpty, reason: '막대가 다시 스크롤 뒤로 숨었다');
  });

  testWidgets('x축 연도 라벨이 두 줄로 접히지 않는다', (tester) async {
    await pump(tester, width: 320);

    // 막대를 폭에 맞추면서 칸이 좁아졌다. 그냥 두면 "'20" 이 "'2"/"0" 으로
    // 접혀서 축이 뭉갠 것처럼 보인다.
    final yearLabels = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .where((t) => (t.data ?? '').startsWith("'"))
        .toList();
    expect(yearLabels, isNotEmpty, reason: '연도 라벨이 아예 없다');
    for (final t in yearLabels) {
      expect(t.maxLines, 1, reason: '${t.data} 가 접힐 수 있다');
      expect(t.softWrap, isFalse, reason: '${t.data} 가 접힐 수 있다');
    }
  });
}
