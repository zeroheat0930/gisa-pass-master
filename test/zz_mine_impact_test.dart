import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/widgets/answer_effect.dart';

void main() {
  testWidgets('overlay show -> exception? onComplete fires?', (tester) async {
    bool completed = false;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('base'));
      }),
    ));

    AnswerEffectOverlay.show(ctx, isCorrect: true, onComplete: () {
      completed = true;
    });
    await tester.pump();

    final err = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION_AFTER_PUMP: ${err.runtimeType} :: $err');

    // 이펙트가 보이는가?
    // ignore: avoid_print
    print('FINDS_정답_LABEL: ${find.text('정답!').evaluate().length}');
    // ignore: avoid_print
    print('FINDS_ERRORWIDGET: ${find.byType(ErrorWidget).evaluate().length}');
    // ignore: avoid_print
    print('FINDS_ANSWEREFFECT: ${find.byType(AnswerEffect).evaluate().length}');

    // 애니메이션 종료까지 진행
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final e = tester.takeException();
      if (e != null) {
        // ignore: avoid_print
        print('EXCEPTION_AT_${i}00ms: $e');
      }
    }
    // ignore: avoid_print
    print('ONCOMPLETE_FIRED: $completed');

    AnswerEffectOverlay.dismiss();
    await tester.pump();
  });
}
