import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/services/answer_checker.dart';

Question q({
  required String type,
  required String text,
  required String answer,
}) =>
    Question(
      year: 2026,
      round: 3,
      subject: '테스트',
      questionType: type,
      questionText: text,
      answer: answer,
      explanation: '',
    );

void main() {
  // ── v1.5.4 회귀 방지 ─────────────────────────────────────────────────────
  // 실제 문제 데이터 1000문항 중 125문항은 정답에 줄바꿈이 있다(실행 결과 문제).
  // 문제은행 탭이 단순 문자열 비교를 써서 이 문항들이 무엇을 입력해도 오답이었다.
  group('여러 줄 정답 — 문제은행 오답 처리 버그', () {
    final output = q(
      type: 'code_reading',
      text: '다음 Java 프로그램의 실행 결과를 쓰시오.',
      answer: '3\n1',
    );

    test('줄바꿈 정답을 그대로 입력하면 정답', () {
      expect(AnswerChecker.isCorrectFor(output, '3\n1'), isTrue);
    });

    test('줄바꿈 대신 쉼표로 입력해도 정답', () {
      expect(AnswerChecker.isCorrectFor(output, '3,1'), isTrue);
      expect(AnswerChecker.isCorrectFor(output, '3, 1'), isTrue);
    });

    test('윈도우 개행(CRLF)도 처리한다', () {
      expect(AnswerChecker.isCorrectFor(output, '3\r\n1'), isTrue);
    });

    test('항목 경계가 사라지는 입력은 정답으로 보지 않는다', () {
      // "35" 는 값 35 인지 두 줄 출력 3,5 인지 구분할 수 없다.
      // 쉼표까지 지워 비교하면 서로 다른 문항의 정답이 충돌한다.
      expect(AnswerChecker.isCorrectFor(output, '31'), isFalse);
      expect(AnswerChecker.isCorrectFor(output, '3 1'), isFalse);
    });

    test('여러 줄 정답에 실제 오답은 여전히 오답', () {
      expect(AnswerChecker.isCorrectFor(output, '3\n2'), isFalse);
      expect(AnswerChecker.isCorrectFor(output, '5'), isFalse);
      expect(AnswerChecker.isCorrectFor(output, ''), isFalse);
    });
  });

  // ── 순서 채점 ────────────────────────────────────────────────────────────
  // 과거에는 나열 순서를 항상 무시해서, 실행 결과의 출력 순서가 뒤바뀐 오답이
  // 정답 처리됐다(감사에서 269문항 영향으로 지목됨).
  group('순서가 채점 대상인 문제', () {
    test('실행 결과는 출력 순서가 다르면 오답', () {
      final output = q(
        type: 'code_reading',
        text: '다음 Java 프로그램의 실행 결과를 쓰시오.',
        answer: '3\n1',
      );
      expect(AnswerChecker.isCorrectFor(output, '1\n3'), isFalse);
    });

    test('"순서대로 쓰시오" 문항은 순서가 다르면 오답', () {
      final ordered = q(
        type: 'short_answer',
        text: 'TCP의 3-way handshake에서 사용되는 3개의 플래그를 순서대로 쓰시오.',
        answer: 'SYN, SYN+ACK, ACK',
      );
      expect(AnswerChecker.isCorrectFor(ordered, 'SYN, SYN+ACK, ACK'), isTrue);
      expect(AnswerChecker.isCorrectFor(ordered, 'ACK, SYN, SYN+ACK'), isFalse);
    });

    test('SQL 결과 행도 순서를 지킨다', () {
      final sql = q(
        type: 'sql',
        text: '부서별 급여 합계를 내림차순으로 조회한 결과를 쓰시오.',
        answer: '개발, 6000\n영업, 4500',
      );
      expect(AnswerChecker.isCorrectFor(sql, '개발, 6000\n영업, 4500'), isTrue);
      expect(AnswerChecker.isCorrectFor(sql, '영업, 4500\n개발, 6000'), isFalse);
    });
  });

  group('순서를 무시해도 되는 문제', () {
    final unordered = q(
      type: 'short_answer',
      text: '트랜잭션의 ACID 특성 4가지를 모두 쓰시오.',
      answer: '원자성, 일관성, 독립성, 지속성',
    );

    test('"모두 쓰시오" 문항은 순서가 달라도 정답', () {
      expect(
        AnswerChecker.isCorrectFor(unordered, '지속성, 독립성, 일관성, 원자성'),
        isTrue,
      );
    });

    test('항목이 모자라면 오답', () {
      expect(AnswerChecker.isCorrectFor(unordered, '원자성, 일관성, 독립성'), isFalse);
    });

    test('중복으로 개수만 맞춘 답은 오답', () {
      // Set 으로 비교하면 중복이 사라져 통과해버린다. 다중집합으로 비교해야 한다.
      final dup = q(
        type: 'short_answer',
        text: '출력되는 값을 모두 쓰시오.',
        answer: 'a, a, b',
      );
      expect(AnswerChecker.isCorrectFor(dup, 'a, b, b'), isFalse);
      expect(AnswerChecker.isCorrectFor(dup, 'a, a, b'), isTrue);
    });
  });

  group('기존 채점 규칙 유지', () {
    test('대소문자·앞뒤 공백 무시', () {
      final t = q(type: 'short_answer', text: '용어를 쓰시오.', answer: 'stack');
      expect(AnswerChecker.isCorrectFor(t, '  Stack  '), isTrue);
    });

    test('내부 공백 차이 흡수', () {
      final t = q(type: 'short_answer', text: '용어를 쓰시오.', answer: '상호배제');
      expect(AnswerChecker.isCorrectFor(t, '상호 배제'), isTrue);
    });

    test('전혀 다른 답은 오답', () {
      final t = q(type: 'short_answer', text: '용어를 쓰시오.', answer: '스택');
      expect(AnswerChecker.isCorrectFor(t, '큐'), isFalse);
    });
  });
}
