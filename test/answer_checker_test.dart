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

    test('ORDER BY 가 있는 SQL 은 행 순서를 지킨다', () {
      // 순서 판정은 지문 문구가 아니라 실제 쿼리(codeSnippet)의 ORDER BY 로 한다.
      final sql = Question(
        year: 2026,
        round: 3,
        subject: '테스트',
        questionType: 'sql',
        questionText: '부서별 급여 합계를 내림차순으로 조회한 결과를 쓰시오.',
        codeSnippet:
            'SELECT 부서, SUM(급여) FROM 사원 GROUP BY 부서 ORDER BY SUM(급여) DESC;',
        answer: '개발, 6000\n영업, 4500',
        explanation: '',
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

  group('괄호 안 대체표기', () {
    Question paren(String answer) => q(
          type: 'short_answer',
          text: '용어를 쓰시오.',
          answer: answer,
        );

    test('괄호를 뺀 표기도 정답', () {
      expect(AnswerChecker.isCorrectFor(paren('스택(stack)'), '스택'), isTrue);
    });

    test('괄호 안 표기만 써도 정답', () {
      expect(AnswerChecker.isCorrectFor(paren('스택(stack)'), 'stack'), isTrue);
    });

    test('원문 그대로도 정답', () {
      expect(AnswerChecker.isCorrectFor(paren('스택(stack)'), '스택(stack)'), isTrue);
    });

    test('엉뚱한 답은 여전히 오답', () {
      expect(AnswerChecker.isCorrectFor(paren('스택(stack)'), '큐'), isFalse);
    });
  });

  // v1.5.4 QA 회귀 — 순서를 엄격하게 바꾸면서 실제로는 순서가 무관한 문항까지
  // 오답 처리하게 됐다. 데이터 실측: SQL 33문항(ORDER BY 없음) + 단답형 13문항("N가지").
  group('SQL 결과 행 순서', () {
    test('ORDER BY 가 없으면 행 순서가 달라도 정답', () {
      final target = Question(
        year: 2026, round: 3, subject: '테스트', questionType: 'sql',
        questionText: '다음 SQL의 실행 결과를 쓰시오.',
        codeSnippet: 'SELECT 부서, SUM(급여) FROM 사원 GROUP BY 부서;',
        answer: '개발, 6000\n영업, 4500', explanation: '',
      );
      expect(AnswerChecker.isCorrectFor(target, '개발, 6000\n영업, 4500'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, '영업, 4500\n개발, 6000'), isTrue,
          reason: 'ORDER BY 가 없으면 행 순서는 보장되지 않는다');
    });

    test('행 안의 컬럼 순서까지 흐트러지면 오답', () {
      final target = Question(
        year: 2026, round: 3, subject: '테스트', questionType: 'sql',
        questionText: '다음 SQL의 실행 결과를 쓰시오.',
        codeSnippet: 'SELECT 부서, SUM(급여) FROM 사원 GROUP BY 부서;',
        answer: '개발, 6000\n영업, 4500', explanation: '',
      );
      expect(AnswerChecker.isCorrectFor(target, '6000, 개발\n4500, 영업'), isFalse,
          reason: '한 행 안의 컬럼 순서는 지켜야 한다');
    });

    test('ORDER BY 가 있으면 행 순서를 지켜야 한다', () {
      final target = Question(
        year: 2026, round: 3, subject: '테스트', questionType: 'sql',
        questionText: '다음 SQL의 실행 결과를 쓰시오.',
        codeSnippet: 'SELECT 고객, SUM(금액) FROM 주문 GROUP BY 고객 ORDER BY 2 DESC;',
        answer: '이, 6000\n박, 5000', explanation: '',
      );
      expect(AnswerChecker.isCorrectFor(target, '이, 6000\n박, 5000'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, '박, 5000\n이, 6000'), isFalse);
    });
  });

  group('"N가지를 쓰시오" 문항', () {
    test('순서가 달라도 정답', () {
      final target = q(
        type: 'short_answer',
        text: '위험 관리에서 위험 대응 전략 4가지를 쓰시오.',
        answer: '회피, 전이, 완화, 수용',
      );
      expect(AnswerChecker.isCorrectFor(target, '수용, 완화, 전이, 회피'), isTrue);
    });

    test('"각각 쓰시오" 는 여전히 순서를 지켜야 한다', () {
      final target = q(
        type: 'short_answer',
        text: 'HTTP의 기본 포트 번호와 HTTPS의 기본 포트 번호를 각각 쓰시오.',
        answer: '80, 443',
      );
      expect(AnswerChecker.isCorrectFor(target, '80, 443'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, '443, 80'), isFalse,
          reason: '지문의 순서와 짝이 맞아야 한다');
    });
  });

  // ── 항목별 설명 괄호 — 실제 데이터 short[343,353,354], sql[108,163] ──────
  // "POST(Create), GET(Read)" 의 괄호는 항목별 부연이지 답의 일부가 아니다.
  // 기존 괄호 게이트는 '괄호 정확히 1쌍 + 답 끝'만 허용해서, 항목마다 괄호가
  // 붙은 정답에서는 괄호를 뺀 교과서적 정답이 오답 처리됐다.
  group('항목별 설명 괄호가 붙은 나열형 정답', () {
    test('CRUD 4가지: 괄호 없이 메서드만 써도 정답 (short[354])', () {
      final target = q(
        type: 'short_answer',
        text: 'REST API에서 CRUD에 대응하는 HTTP 메서드 4가지를 쓰시오.',
        answer: 'POST(Create), GET(Read), PUT(Update), DELETE(Delete)',
      );
      expect(AnswerChecker.isCorrectFor(target, 'POST, GET, PUT, DELETE'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, 'GET, POST, PUT, DELETE'), isTrue,
          reason: '"4가지" 나열형은 순서 무관');
      expect(AnswerChecker.isCorrectFor(target, 'POST, GET, PUT'), isFalse,
          reason: '하나 빠지면 오답');
    });

    test('2PL 두 단계: 괄호 설명 없이 단계 이름만 써도 정답 (short[353])', () {
      final target = q(
        type: 'short_answer',
        text: '2단계 로킹 프로토콜(2PL)의 두 단계를 쓰시오.',
        answer: '확장 단계(Lock만 가능), 축소 단계(Unlock만 가능)',
      );
      expect(AnswerChecker.isCorrectFor(target, '확장 단계, 축소 단계'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, '확장 단계(Lock만 가능), 축소 단계'),
          isTrue, reason: '일부 항목만 괄호를 생략해도 정답');
    });

    test('sql 유형의 이론 문항도 동일하게 인정한다 (sql[163])', () {
      const answer = '보안(접근 제한), 쿼리 단순화, 데이터 독립성';
      const text = '뷰(VIEW)를 사용하는 이유 3가지를 쓰시오.';
      expect(
          AnswerChecker.isCorrect('보안, 쿼리 단순화, 데이터 독립성', answer,
              questionType: 'sql', questionText: text),
          isTrue);
    });

    test('실행 결과 문제의 괄호는 여전히 출력 구문이다', () {
      final target = q(
        type: 'code_reading',
        text: '다음 Python 프로그램의 실행 결과를 쓰시오.',
        answer: '(1, 2), (3, 4)',
      );
      expect(AnswerChecker.isCorrectFor(target, '1, 3'), isFalse);
      expect(AnswerChecker.isCorrectFor(target, ', '), isFalse);
    });
  });

  // ── "(또는 X)" 는 앞 단어의 대체어다 — 실제 데이터 short[346] ────────────
  group('"(또는 X)" 대체어 표기', () {
    final target = q(
      type: 'short_answer',
      text: 'CI/CD에서 CI와 CD가 각각 무엇의 약자인지 쓰시오.',
      answer: 'Continuous Integration, Continuous Delivery(또는 Deployment)',
    );

    test('정답 데이터가 허용한 대체어로 쓰면 정답', () {
      expect(
          AnswerChecker.isCorrectFor(
              target, 'Continuous Integration, Continuous Deployment'),
          isTrue);
    });

    test('괄호 원문을 그대로 쓰거나 괄호를 빼도 정답', () {
      expect(
          AnswerChecker.isCorrectFor(target,
              'Continuous Integration, Continuous Delivery(또는 Deployment)'),
          isTrue);
      expect(
          AnswerChecker.isCorrectFor(
              target, 'Continuous Integration, Continuous Delivery'),
          isTrue);
    });

    test('"또는 Deployment" 만 달랑 쓰면 오답', () {
      expect(AnswerChecker.isCorrectFor(target, '또는 Deployment'), isFalse,
          reason: '괄호 안 문구는 전체 답의 대체표기가 아니다');
    });
  });

  // ── C 의 +32 관용구 — 실제 데이터 c[11], c[127] ──────────────────────────
  // s[i]+32 로 소문자화하는 문항에서 대소문자를 접으면, 입력 문자열 "ABCDE" 를
  // 그대로 옮겨 적어도 정답이 되어 출제 의도가 사라진다.
  group('C 의 ±32 대소문자 변환 문항', () {
    test('printf("%c", s[i]+32) 문항은 대소문자를 채점한다 (c[11])', () {
      const snippet = '#include <stdio.h>\n'
          'int main() {\n'
          '    char s[] = "ABCDE";\n'
          '    int i;\n'
          "    for(i=0; s[i]!='\\0'; i++)\n"
          '        printf("%c", s[i]+32);\n'
          '    return 0;\n'
          '}';
      expect(
          AnswerChecker.isCorrect('abcde', 'abcde',
              questionType: 'code_reading',
              questionText: '다음 C 프로그램의 실행 결과를 쓰시오.',
              codeSnippet: snippet),
          isTrue);
      expect(
          AnswerChecker.isCorrect('ABCDE', 'abcde',
              questionType: 'code_reading',
              questionText: '다음 C 프로그램의 실행 결과를 쓰시오.',
              codeSnippet: snippet),
          isFalse,
          reason: '입력 문자열을 그대로 옮겨 적으면 오답이어야 한다');
    });

    test('s[i] = s[i] + 32 처럼 띄어 쓴 형태도 잡는다 (c[127])', () {
      const snippet = '#include <stdio.h>\n'
          'int main() {\n'
          '    char s[] = "ABCDE";\n'
          '    int i = 0;\n'
          "    while (s[i] != '\\0') {\n"
          '        s[i] = s[i] + 32;\n'
          '        i++;\n'
          '    }\n'
          '    printf("%s", s);\n'
          '    return 0;\n'
          '}';
      expect(
          AnswerChecker.isCorrect('ABCDE', 'abcde',
              questionType: 'code_reading',
              questionText: '다음 C 프로그램의 실행 결과를 쓰시오.',
              codeSnippet: snippet),
          isFalse);
    });
  });
}
