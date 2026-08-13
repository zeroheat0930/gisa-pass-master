@Tags(['probe'])
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/services/answer_checker.dart';

/// 채점이 유저에게 얼마나 가혹한지 재는 **측정용 프로브**다. 합격/불합격을
/// 주장하지 않고 숫자만 찍는다 (`flutter test --tags probe` 로만 돌린다).
///
/// 유저가 "직접 풀어보니 다 틀린다" 고 했다. 추측하지 말고, 사람이 쓸 법한
/// 답안을 실제 채점기에 넣어 몇 개가 오답 처리되는지 센다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final List<Question> restored;

  setUpAll(() async {
    final raw = await rootBundle
        .loadString('assets/questions/restored_exam_questions.json');
    restored = (json.decode(raw) as List)
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
              source: Question.sourceRestored,
            ))
        .toList();
  });

  /// 줄머리 번호를 뗀다: "1. 문장" -> "문장", "(1) 외래키" -> "외래키",
  /// "① 준비" -> "준비", "ㄹ. Ad-hoc" -> "Ad-hoc".
  /// 숫자 뒤에 **공백이 있어야** 번호로 본다 — "6.5ms" 를 깨뜨리지 않기 위해서다.
  String stripItemNumbers(String answer) => answer
      .split('\n')
      .map((l) => l.replaceFirst(
          RegExp(r'^\s*(\(\d+\)|\d+[.)]|[①-⑳]|[ㄱ-ㅎ][.)])\s+'), ''))
      .join('\n');

  /// 끝에 붙은 괄호 표기를 뗀다: "동치분할(Equivalence Partitioning)" -> "동치분할".
  String stripTrailingParen(String answer) =>
      answer.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();

  test('사람이 쓸 법한 답안이 몇 개나 오답 처리되는가', () {
    var numberedTotal = 0, numberedRejected = 0;
    var parenTotal = 0, parenRejected = 0;
    final samples = <String>[];

    for (final q in restored) {
      // 1) 번호를 빼고 쓴 답
      final noNum = stripItemNumbers(q.answer);
      if (noNum != q.answer) {
        numberedTotal++;
        if (!AnswerChecker.isCorrectFor(q, noNum)) {
          numberedRejected++;
          if (samples.length < 8) {
            samples.add('[번호뺌] ${q.year}-${q.round}\n'
                '   정답: ${jsonEncode(q.answer)}\n'
                '   입력: ${jsonEncode(noNum)}');
          }
        }
      }

      // 2) 괄호 표기를 빼고 쓴 답
      final noParen = stripTrailingParen(q.answer);
      if (noParen != q.answer && noParen.isNotEmpty) {
        parenTotal++;
        if (!AnswerChecker.isCorrectFor(q, noParen)) {
          parenRejected++;
          if (samples.length < 8) {
            samples.add('[괄호뺌] ${q.year}-${q.round}\n'
                '   정답: ${jsonEncode(q.answer)}\n'
                '   입력: ${jsonEncode(noParen)}');
          }
        }
      }
    }

    // ignore: avoid_print
    print('\n=== 복원 기출 ${restored.length}문항 채점 가혹도 ===');
    // ignore: avoid_print
    print('번호를 빼고 쓴 답: $numberedTotal건 중 $numberedRejected건 오답 처리');
    // ignore: avoid_print
    print('괄호를 빼고 쓴 답: $parenTotal건 중 $parenRejected건 오답 처리');
    // ignore: avoid_print
    print('\n--- 사례 ---\n${samples.join('\n')}\n');
  });

  test('정답을 글자 그대로 쳐도 맞는지 (최소 보증)', () {
    final broken = <String>[];
    for (final q in restored) {
      if (!AnswerChecker.isCorrectFor(q, q.answer)) {
        broken.add('${q.year}-${q.round}: ${jsonEncode(q.answer)}');
      }
    }
    expect(broken, isEmpty, reason: '등록된 답 그대로도 틀린다:\n${broken.join('\n')}');
  });
}
