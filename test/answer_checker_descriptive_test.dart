import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/answer_checker.dart';

/// 서술형 채점의 양쪽 실패를 다 막는다.
///
/// "스니핑에 대해 서술하시오" 같은 문항은 모범답안을 글자까지 똑같이 쓸 수 없어
/// 예전에는 무조건 오답이었다. 그렇다고 관대하게 풀면 **내용이 빈 답도 정답이
/// 되어 앱이 실력을 거짓으로 말한다.** 그래서 제대로 쓴 의역은 통과하고,
/// 핵심어 몇 개만 스친 답은 떨어지는지 둘 다 확인한다.
void main() {
  bool grade(String question, String correct, String user) =>
      AnswerChecker.isCorrect(user, correct,
          questionType: 'short_answer', questionText: question);

  group('제대로 쓴 의역은 정답으로 본다', () {
    test('스니핑 — 표현이 달라도 핵심이 같으면 맞다', () {
      const q = '스니핑(Sniffing)에 대하여 서술하시오.';
      const a = '네트워크에서 암호화되지 않은 패킷을 몰래 수집·재조합하여 ID, 비밀번호 등 '
          '중요한 정보를 훔쳐내는 수동적 형태의 공격';

      expect(
        grade(q, a,
            '네트워크에서 암호화되지 않은 패킷을 수집하고 재조합해서 비밀번호 같은 중요한 정보를 '
            '훔쳐내는 수동적인 공격이다'),
        isTrue,
      );
    });

    test('원자성 — 어순이 달라도 맞다', () {
      const q = '트랜잭션의 특징 중, 원자성에 대해 약술하시오.';
      const a = '트랜잭션의 연산은 모두 반영되거나 아니면 전혀 반영되지 않아야 한다는 성질';

      expect(
        grade(q, a, '트랜잭션의 연산이 전부 반영되거나 전혀 반영되지 않아야 한다는 성질이다'),
        isTrue,
      );
    });

    test('가용성 — 조사가 달라도 맞다', () {
      const q = '정보보안에서 가용성(Availability)에 대하여 서술하시오.';
      const a = '인가된 사용자가 필요할 때 언제든 정보와 서비스를 지속적으로 사용할 수 있도록 '
          '보장하는 특성';

      expect(
        grade(q, a, '인가된 사용자는 필요할 때 언제든 정보와 서비스를 지속적으로 쓸 수 있어야 '
            '한다는 것을 보장하는 특성'),
        isTrue,
      );
    });

    test('모범답안을 그대로 써도 당연히 맞다', () {
      const q = 'DB 스키마에 대해서 서술하시오.';
      const a = '데이터베이스의 구조와 제약조건 등에 관한 명세를 기술한 것';
      expect(grade(q, a, a), isTrue);
    });
  });

  group('내용이 빈 답은 오답으로 둔다', () {
    test('핵심어 한두 개만 스친 답은 틀리다', () {
      const q = '스니핑(Sniffing)에 대하여 서술하시오.';
      const a = '네트워크에서 암호화되지 않은 패킷을 몰래 수집·재조합하여 ID, 비밀번호 등 '
          '중요한 정보를 훔쳐내는 수동적 형태의 공격';

      expect(grade(q, a, '네트워크 공격'), isFalse);
      expect(grade(q, a, '패킷을 보는 것'), isFalse);
    });

    test('아예 다른 개념을 쓰면 틀리다', () {
      const q = '트랜잭션의 특징 중, 원자성에 대해 약술하시오.';
      const a = '트랜잭션의 연산은 모두 반영되거나 아니면 전혀 반영되지 않아야 한다는 성질';

      expect(grade(q, a, '트랜잭션이 성공하면 결과가 영구히 반영되는 성질'), isFalse,
          reason: '지속성 설명이 원자성 정답이 되면 안 된다');
    });

    test('질문을 그대로 베껴 써도 틀리다', () {
      const q = '리팩토링의 목적에 대하여 서술하시오.';
      const a = '기능은 그대로 두고 복잡한 코드를 단순화하여 가독성과 유지보수성을 높이고, '
          '유연한 구조로 만들어 생산성과 품질을 향상시키는 것';

      expect(grade(q, a, '리팩토링의 목적'), isFalse);
    });

    test('빈 답은 틀리다', () {
      const q = 'DB 스키마에 대해서 서술하시오.';
      const a = '데이터베이스의 구조와 제약조건 등에 관한 명세를 기술한 것';
      expect(grade(q, a, ''), isFalse);
      expect(grade(q, a, '   '), isFalse);
    });
  });

  group('서술형이 아닌 문항에는 이 완화가 적용되지 않는다', () {
    test('용어 단답형은 여전히 정확히 맞아야 한다', () {
      // 이 완화가 단답형까지 번지면 "네트워크 프로토콜" 같은 두루뭉술한 답이
      // 정답 처리되어 채점이 무의미해진다.
      expect(
        AnswerChecker.isCorrect('주소를 바꿔주는 네트워크 기술', 'NAT',
            questionType: 'short_answer', questionText: '다음이 설명하는 기술은?'),
        isFalse,
      );
    });

    test('실행 결과 문항은 여전히 정확히 맞아야 한다', () {
      expect(
        AnswerChecker.isCorrect('대충 5쯤', '5',
            questionType: 'code_reading',
            questionText: '출력 결과를 서술하시오.'),
        isFalse,
      );
    });
  });
}
