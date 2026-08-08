import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/models/study_stats.dart';
import 'package:gisa_pass_master/widgets/pass_score_card.dart';

/// QA 프로브가 잡아낸 회귀: 좁은 화면 + 큰 글씨 배율에서 카드가 93px 넘쳤다.
/// 접근성 설정으로 글씨를 키운 유저에게 레이아웃이 깨져 보이면 안 된다.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required double width,
    required double textScale,
    required StudyStats stats,
  }) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: PassScoreCard(stats: stats),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final withData = StudyStats(
    totalSolved: 300,
    totalCorrect: 200,
    totalAvailable: 1000,
  );
  final noData = StudyStats(totalAvailable: 1000);

  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('W$width · 글씨배율 $scale — 넘치지 않는다', (tester) async {
        await pumpCard(tester,
            width: width, textScale: scale, stats: withData);
        expect(tester.takeException(), isNull,
            reason: 'RenderFlex overflow 가 나면 안 된다');
      });
    }
  }

  testWidgets('데이터 부족 상태도 좁은 화면에서 넘치지 않는다', (tester) async {
    await pumpCard(tester, width: 320, textScale: 2.0, stats: noData);
    expect(tester.takeException(), isNull);
  });

  testWidgets('점수가 진행바에 반영된다', (tester) async {
    await pumpCard(tester, width: 390, textScale: 1.0, stats: withData);

    // 진행바가 항상 꽉 찬 상태로 고정되어 있으면 점수 표시가 무의미하다.
    final bars = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox));
    expect(bars, isNotEmpty);
    expect(bars.any((b) => (b.widthFactor ?? 1.0) < 1.0), isTrue,
        reason: '진행바가 점수 비율만큼 채워져야 한다');
  });
}
