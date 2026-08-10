import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/widgets/question_card.dart';

// QuestionCard 헤더 Row(과목 배지 + 유형 배지 + 'AI 예측')가 좁은 화면·큰 글씨에서
// 우측으로 넘치던 회귀 방지. 감사 프로브가 W320 × 배율 1.2 부터 RenderFlex
// 오버플로(69~89px)를 잡아냈다. 배지를 Flexible 로 감싸지 않으면 재현된다.
void main() {
  Future<void> pumpAt(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final question = Question(
      year: 2026,
      round: 3,
      subject: '데이터베이스 구축',
      questionType: 'code_reading',
      questionText: '다음 프로그램의 실행 결과를 쓰시오.',
      answer: '1',
      explanation: '',
    );

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: QuestionCard(question: question),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull,
        reason: 'W$width × 배율 $textScale 에서 오버플로가 나면 안 된다');
  }

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('QuestionCard W$width / 배율 $scale', (tester) async {
        await pumpAt(tester, width: width, textScale: scale);
      });
    }
  }
}
