import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/models/study_stats.dart';
import 'package:gisa_pass_master/services/answer_checker.dart';
import 'package:gisa_pass_master/utils/duration_format.dart';

void main() {
  // 화면마다 복붙된 remainder(60) 계산이 '시' 단위를 버려서, 1시간 넘게 푼
  // 모의고사의 '소요 시간'이 거짓값으로 찍혔다.
  group('경과 시간 표기', () {
    test('1시간 미만은 mm:ss', () {
      expect(formatElapsed(const Duration(minutes: 3, seconds: 7)), '03:07');
      expect(formatElapsed(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('1시간 이상은 시 단위를 버리지 않는다', () {
      expect(formatElapsed(const Duration(hours: 1)), '1:00:00');
      expect(
          formatElapsed(const Duration(hours: 1, minutes: 12, seconds: 5)),
          '1:12:05');
      expect(formatElapsed(const Duration(hours: 2, minutes: 3)), '2:03:00');
    });

    test('0과 음수도 안전하다', () {
      expect(formatElapsed(Duration.zero), '00:00');
      expect(formatElapsed(const Duration(seconds: -5)), '00:00');
    });
  });

  // 완료율에 총 풀이 수를 쓰면 같은 문제를 여러 번 풀 때마다 진도가 올라
  // "1500 / 1000" 같은 값이 표시됐다.
  group('전체 문제 완료율', () {
    test('중복 풀이는 진도를 올리지 않는다', () {
      final stats = StudyStats(
        totalSolved: 1500, // 총 풀이 수 (중복 포함)
        uniqueSolved: 300, // 서로 다른 문제
        totalAvailable: 1000,
      );
      expect(stats.completionLabel, '300 / 1000');
      expect(stats.completionRate, closeTo(0.3, 0.0001));
    });

    test('총 문항 수를 넘겨 표시하지 않는다', () {
      final stats = StudyStats(
        totalSolved: 5000,
        uniqueSolved: 1200, // 데이터 이상으로 초과한 경우
        totalAvailable: 1000,
      );
      expect(stats.completionLabel, '1000 / 1000');
      expect(stats.completionRate, 1.0);
    });

    test('푼 문제가 없으면 0', () {
      final stats = StudyStats(totalAvailable: 1000);
      expect(stats.completionLabel, '0 / 1000');
      expect(stats.completionRate, 0);
    });
  });

  // 대소문자 변환 결과를 묻는 문항에서 대소문자를 접으면, 입력 문자열을 그대로
  // 옮겨 적어도 정답이 되어 문제가 성립하지 않는다.
  group('대소문자 채점', () {
    Question q(String text, String answer, {String? code}) => Question(
          year: 2026,
          round: 3,
          subject: '테스트',
          questionType: 'code_reading',
          questionText: text,
          codeSnippet: code,
          answer: answer,
          explanation: '',
        );

    test('대문자 변환 문항은 대소문자를 구분한다', () {
      final target = q(
        '다음 프로그램의 실행 결과를 쓰시오.',
        'HELLO',
        code: 'System.out.print("hello".toUpperCase());',
      );
      expect(AnswerChecker.isCorrectFor(target, 'HELLO'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, 'hello'), isFalse,
          reason: '입력 문자열을 그대로 적은 것은 오답이어야 한다');
    });

    test('지문에 "대문자"가 있어도 구분한다', () {
      final target = q('문자열을 대문자로 바꾼 결과를 쓰시오.', 'ABC');
      expect(AnswerChecker.isCorrectFor(target, 'abc'), isFalse);
      expect(AnswerChecker.isCorrectFor(target, 'ABC'), isTrue);
    });

    test('평범한 문항은 여전히 대소문자를 무시한다', () {
      final target = q('출력 결과를 쓰시오.', 'Stack');
      expect(AnswerChecker.isCorrectFor(target, 'stack'), isTrue);
      expect(AnswerChecker.isCorrectFor(target, 'STACK'), isTrue);
    });
  });
}
