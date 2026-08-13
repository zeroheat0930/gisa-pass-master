import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/answer_checker.dart';
import 'package:gisa_pass_master/widgets/answer_input_field.dart';

/// 답이 여러 개인 문항에서 칸이 하나뿐이라 유저가 어떻게 나눠 넣어야 할지
/// 알 수 없던 문제의 회귀 방지.
///
/// 이 위젯은 세 화면(quiz / past_exam / ai_prediction)이 공유한다.
/// **바깥 계약(컨트롤러 하나에 답이 모인다)이 깨지면 세 화면이 전부 조용히
/// 오답을 내므로** 그 계약을 여기서 지킨다.
void main() {
  Future<TextEditingController> pump(
    WidgetTester tester,
    String correctAnswer, {
    VoidCallback? onSubmit,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnswerInputField(
            controller: controller,
            correctAnswer: correctAnswer,
            onSubmit: onSubmit ?? () {},
          ),
        ),
      ),
    ));
    return controller;
  }

  group('칸을 나누는 기준', () {
    testWidgets('번호가 붙은 정답은 번호 수만큼 칸을 만든다', (tester) async {
      await pump(tester, '1. 문장\n2. 분기\n3. 조건');

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('답이 3개입니다'), findsOneWidget);
      // 어느 칸이 몇 번인지 라벨로 알 수 있어야 한다.
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
    });

    testWidgets('ㄱ·ㄴ 라벨도 칸으로 나뉜다', (tester) async {
      await pump(tester, 'ㄱ. Bridge\nㄴ. Observer');
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('ㄱ.'), findsOneWidget);
    });

    testWidgets('여러 줄 출력 정답은 칸을 나누지 않는다', (tester) async {
      // "3\n1" 은 답이 둘인 게 아니라 프로그램이 두 줄을 출력한 것이다.
      await pump(tester, '3\n1');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('답이'), findsNothing);
    });

    testWidgets('한 줄 정답은 칸 하나 그대로다', (tester) async {
      await pump(tester, 'NAT');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('소수점이 있는 정답을 번호로 오해하지 않는다', (tester) async {
      await pump(tester, '6.5ms');
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('바깥 컨트롤러와의 계약', () {
    testWidgets('칸에 넣은 값이 컨트롤러 하나로 모인다', (tester) async {
      final controller = await pump(tester, '1. 문장\n2. 분기\n3. 조건');

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '문장');
      await tester.enterText(fields.at(1), '분기');
      await tester.enterText(fields.at(2), '조건');
      await tester.pump();

      expect(controller.text, '문장\n분기\n조건');
    });

    testWidgets('그렇게 모인 답이 실제로 정답 처리된다', (tester) async {
      // 위젯과 채점기가 따로 놀면 유저는 맞게 넣고도 틀린다.
      const correct = '1. 문장\n2. 분기\n3. 조건';
      final controller = await pump(tester, correct);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '문장');
      await tester.enterText(fields.at(1), '분기');
      await tester.enterText(fields.at(2), '조건');
      await tester.pump();

      expect(
        AnswerChecker.isCorrect(controller.text, correct,
            questionType: 'short_answer'),
        isTrue,
      );
    });

    testWidgets('다음 문제로 넘어가며 컨트롤러를 비우면 칸도 비워진다', (tester) async {
      final controller = await pump(tester, '1. 가\n2. 나');

      await tester.enterText(find.byType(TextField).at(0), '가');
      await tester.pump();
      expect(controller.text, isNotEmpty);

      // 화면이 다음 문제로 넘어갈 때 하는 일
      controller.clear();
      await tester.pump();

      final first = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(first.controller!.text, isEmpty,
          reason: '앞 문제의 답이 다음 문제 칸에 남으면 안 된다');
    });

    testWidgets('정답이 바뀌면 칸 구성이 다시 잡힌다', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      Widget build(String answer) => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnswerInputField(
                  controller: controller,
                  correctAnswer: answer,
                  onSubmit: () {},
                ),
              ),
            ),
          );

      await tester.pumpWidget(build('1. 가\n2. 나\n3. 다'));
      expect(find.byType(TextField), findsNWidgets(3));

      await tester.pumpWidget(build('NAT'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget,
          reason: '다음 문제가 단답형이면 칸도 하나여야 한다');
    });
  });

  group('제출', () {
    testWidgets('마지막 칸에서 엔터를 누르면 제출된다', (tester) async {
      var submitted = 0;
      await pump(tester, '1. 가\n2. 나', onSubmit: () => submitted++);

      await tester.enterText(find.byType(TextField).at(1), '나');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, 1);
    });

    testWidgets('여러 줄 정답에서는 엔터로 제출되지 않는다 (줄바꿈이어야 한다)', (tester) async {
      var submitted = 0;
      await pump(tester, '3\n1', onSubmit: () => submitted++);

      await tester.enterText(find.byType(TextField), '3');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();

      expect(submitted, 0);
    });
  });
}
