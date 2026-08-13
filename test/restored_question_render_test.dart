import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/widgets/question_card.dart';

/// 복원 기출은 원문의 **표와 그림을 텍스트로 옮겨** questionText 에 담는다
/// (앱에 이미지 표시 경로가 없다). 그래서 다른 문항보다 본문이 길고 줄이 많다.
///
/// 기존 question_card_layout_test 는 '다음 프로그램의 실행 결과를 쓰시오.' 라는
/// **짧은 합성 문항** 하나만 렌더링한다. 즉 실제 데이터의 최악 케이스는
/// 화면에 올라가 본 적이 없었다. 여기서 실제 에셋으로 올려본다.
///
/// ⚠️ **에셋 로딩은 반드시 setUpAll 에서 한다.** testWidgets 본문은 FakeAsync 존에서
/// 돌아서 그 안의 rootBundle.loadString(실제 파일 I/O)은 영영 완료되지 않는다.
/// 실패하지도 않고 그냥 매달린다 — 5문항짜리로 줄여도 6분 넘게 멈춰 있었다.
///
/// 전량(420문항 × 여러 배율)을 돌리면 pump 가 천 번을 넘어 느리다. 그래서
/// **깨질 만한 것만** 고른다 — 표가 든 문항, 본문이 긴 문항, 코드가 긴 문항.
/// 짧은 산문 문항은 어차피 자동 줄바꿈되므로 위험 구간이 아니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final List<Question> risky;

  setUpAll(() async {
    final raw = await rootBundle
        .loadString('assets/questions/restored_exam_questions.json');
    final all = (json.decode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map((e) => Question(
              year: e['year'] as int,
              round: e['round'] as int,
              subject: e['subject'] as String,
              questionType: e['questionType'] as String,
              questionText: e['questionText'] as String,
              codeSnippet: e['codeSnippet'] as String?,
              codeLanguage: e['codeLanguage'] as String?,
              answer: e['answer'] as String,
              explanation: e['explanation'] as String? ?? '',
              source: e['source'] as String? ?? Question.sourceAi,
            ))
        .toList();

    bool hasTable(Question q) =>
        q.questionText.split('\n').any((l) => l.split('|').length >= 3);
    int longestLine(Question q) => q.questionText
        .split('\n')
        .fold(0, (m, l) => l.length > m ? l.length : m);

    final picked = <Question>{}
      ..addAll(all.where(hasTable))
      ..addAll(
          (all.toList()..sort((a, b) => longestLine(b).compareTo(longestLine(a))))
              .take(20))
      ..addAll((all.toList()
            ..sort((a, b) =>
                b.questionText.length.compareTo(a.questionText.length)))
          .take(20))
      ..addAll((all.toList()
            ..sort((a, b) => (b.codeSnippet?.length ?? 0)
                .compareTo(a.codeSnippet?.length ?? 0)))
          .take(15));
    risky = picked.toList();
  });

  // W320(가장 좁은 기기) × 배율 2.0(큰 글씨)이 최악 조합이다.
  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('표·장문 복원 기출이 W$width / 배율 $scale 에서 오버플로 없이 그려진다',
        (tester) async {
      // 세로는 SingleChildScrollView 가 받아내므로 넉넉할 필요가 없다.
      tester.view.physicalSize = Size(width * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      expect(risky.length, greaterThan(30), reason: '위험 구간을 너무 적게 골랐다');

      final broken = <String>[];
      for (final q in risky) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: QuestionCard(question: q),
                ),
              ),
            ),
          ),
        );
        final err = tester.takeException();
        if (err != null) broken.add('${q.year}년 ${q.round}회: $err');
      }

      expect(broken, isEmpty,
          reason: '오버플로가 난 문항:\n${broken.take(10).join('\n')}');
    });
  }
}
