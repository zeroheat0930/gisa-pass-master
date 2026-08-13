import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/widgets/question_text.dart';

/// 복원 기출의 표는 원문 이미지를 텍스트로 옮긴 것이라, 열이 어긋나거나 행이
/// 접히면 어느 값이 어느 열인지 알 수 없게 된다. 그 방어선이다.
void main() {
  const style = TextStyle(fontSize: 16, height: 1.6);

  group('표 줄 판별', () {
    test('구분자가 둘 이상이어야 표로 본다', () {
      expect(QuestionText.isTableRow('프로세스 | 도착시간 | 버스트시간'), isTrue);
      expect(QuestionText.isTableRow('P1      | 0       | 8'), isTrue);
    });

    test('파이프가 하나뿐이면 표가 아니다 (평범한 나열을 표로 만들지 않는다)', () {
      expect(QuestionText.isTableRow('가상회선 | 데이터그램'), isFalse);
      expect(QuestionText.isTableRow('파이프가 없는 평범한 문장'), isFalse);
    });

    test('셀의 정렬용 공백은 버린다', () {
      expect(QuestionText.cellsOf('P1      | 0       | 8'), ['P1', '0', '8']);
    });
  });

  Future<void> pump(WidgetTester tester, String text,
      {double width = 320}) async {
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionText(text: text, style: style),
        ),
      ),
    ));
  }

  const sample = '다음 프로세스들을 SRT 스케줄링으로 처리할 때 평균 대기시간을 구하시오.\n'
      '\n'
      '  프로세스 | 도착시간 | 버스트시간\n'
      '  P1      | 0       | 8\n'
      '  P2      | 1       | 4\n'
      '\n'
      '단위는 ms 이다.';

  testWidgets('표 줄은 진짜 Table 로 그려진다', (tester) async {
    await pump(tester, sample);
    expect(find.byType(Table), findsOneWidget,
        reason: '연속한 표 줄은 한 Table 로 묶여야 열 폭이 함께 계산된다');
  });

  testWidgets('열이 레이아웃으로 정렬된다 (폰트에 기대지 않는다)', (tester) async {
    await pump(tester, sample);

    // 같은 열에 속한 셀은 x 좌표가 정확히 같아야 한다.
    // 고정폭 폰트에 의존하던 방식은 iOS 에서 조용히 깨졌다.
    double left(String cell) => tester.getTopLeft(find.text(cell)).dx;

    expect(left('도착시간'), left('0'));
    expect(left('도착시간'), left('1'));
    expect(left('버스트시간'), left('8'));
    expect(left('버스트시간'), left('4'));
  });

  testWidgets('산문은 표로 바뀌지 않고 그대로 남는다', (tester) async {
    await pump(tester, sample);

    final prose = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(prose, contains('평균 대기시간'));
    expect(prose, contains('단위는 ms'));
  });

  testWidgets('좁은 화면에서 표는 접히지 않고 가로로 스크롤된다', (tester) async {
    await pump(tester, sample, width: 320);

    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.horizontal);
    expect(horizontal, isNotEmpty, reason: '넘치는 폭은 스크롤로 흘려야 한다');
  });

  testWidgets('표가 없는 본문은 Table 도 가로 스크롤도 만들지 않는다', (tester) async {
    await pump(tester, '표가 전혀 없는 평범한 지문이다.\n두 번째 줄도 평범하다.');

    expect(find.byType(Table), findsNothing);
    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.horizontal);
    expect(horizontal, isEmpty);
  });

  testWidgets('셀 수가 더 많은 행이 섞여도 깨지지 않는다', (tester) async {
    // 열 수는 가장 긴 행에 맞추고 모자란 칸은 빈 셀로 채운다.
    await pump(tester, 'A | B | C\nD | E | F\nG | H | I | J');
    expect(find.byType(Table), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('파이프가 하나뿐인 줄은 표를 끊는다 (알려진 한계)', (tester) async {
    // 'D | E' 는 구분자가 하나뿐이라 표 행으로 보지 않으므로 블록이 갈린다.
    // 갈린 두 표는 열 폭을 공유하지 않는다.
    //
    // 현재 에셋 1,420문항에는 이 형태가 **한 건도 없어서** 실제로 드러나지 않는다.
    // 판별 기준을 느슨하게 하면 '가상회선 | 데이터그램' 같은 평범한 나열까지
    // 표로 끌려 들어오므로, 지금은 이 한계를 감수하고 기준을 좁게 둔다.
    // 만약 이런 원문이 들어오면 그 줄에 파이프를 하나 더 넣어 맞춰줄 것.
    await pump(tester, 'A | B | C\nD | E\nF | G | H');
    expect(find.byType(Table), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
