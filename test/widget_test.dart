import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/widgets/answer_input_field.dart';

/// v1.5.4 회귀 방지 — 스토어 리뷰로 접수된 "엔터 누르면 답이 제대로 안 된다".
///
/// 전체 1000문항 중 125문항은 정답이 여러 줄이다(실행 결과 문제).
/// 입력창이 한 줄짜리라 줄을 나누려고 엔터를 누르면 줄바꿈 대신 곧바로 제출됐고,
/// 첫 줄만 채점됐다. 그래서 정답의 줄 수에 따라 입력 방식이 달라져야 한다.
///
/// 이 파일은 원래 `test('placeholder', () => expect(1 + 1, 2))` 하나뿐이었다.
/// 위젯 테스트가 없으면 AnswerInputField 의 동작을 통째로 되돌려도 전부 통과한다.
void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required String correctAnswer,
    required TextEditingController controller,
    required VoidCallback onSubmit,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerInputField(
            controller: controller,
            correctAnswer: correctAnswer,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }

  group('한 줄 정답', () {
    testWidgets('엔터가 제출로 동작한다', (tester) async {
      final controller = TextEditingController();
      var submitted = 0;

      await pumpField(tester,
          correctAnswer: '스택', controller: controller, onSubmit: () => submitted++);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 1, reason: '한 줄 정답은 한 줄 입력창이어야 한다');
      expect(field.textInputAction, TextInputAction.done);

      await tester.enterText(find.byType(TextField), '스택');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, 1, reason: '엔터로 제출되어야 한다');
    });
  });

  group('여러 줄 정답', () {
    testWidgets('엔터가 제출을 트리거하지 않는다', (tester) async {
      final controller = TextEditingController();
      var submitted = 0;

      await pumpField(tester,
          correctAnswer: '3\n1',
          controller: controller,
          onSubmit: () => submitted++);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.newline,
          reason: '엔터가 줄바꿈이어야 한다');
      expect(field.maxLines, greaterThan(1),
          reason: '여러 줄을 입력할 수 있어야 한다');
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.onSubmitted, isNull,
          reason: '엔터로 제출되면 첫 줄만 채점되던 버그가 되살아난다');

      expect(submitted, 0);
    });

    testWidgets('줄바꿈이 포함된 답을 그대로 담는다', (tester) async {
      final controller = TextEditingController();

      await pumpField(tester,
          correctAnswer: '3\n1', controller: controller, onSubmit: () {});

      await tester.enterText(find.byType(TextField), '3\n1');
      await tester.pump();

      expect(controller.text, '3\n1');
    });
  });
}
