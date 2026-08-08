import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/config.dart';

/// D-Day 회차 자동 전환.
///
/// 확정 일정이 모두 지나면 마지막 항목을 그대로 반환해서, D-Day 가 영영
/// '시험 완료!' 에 갇히는 문제가 있었다. 이제 통상 시행 시기로 추정해 이어간다.
void main() {
  group('현재 시점 회차', () {
    test('다음 시험은 항상 오늘 이후다', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(AppConfig.examDate.isBefore(today), isFalse,
          reason: '지나간 시험을 가리키면 D-Day 가 멈춘다');
    });

    test('남은 일수는 음수가 되지 않는다', () {
      expect(AppConfig.daysUntilExam, greaterThanOrEqualTo(0));
    });

    test('회차 라벨이 시험일과 같은 연도를 가리킨다', () {
      expect(AppConfig.examRoundLabel, contains('${AppConfig.examDate.year}년'));
    });

    test('회차 번호는 1~3 사이다', () {
      expect(AppConfig.nextExam.round, inInclusiveRange(1, 3));
    });
  });

  group('확정 일정 소진 후 추정', () {
    test('다음 시험이 과거를 가리키지 않는다', () {
      expect(AppConfig.nextExam.date.year,
          greaterThanOrEqualTo(DateTime.now().year));
    });

    test('확정 일정 여부를 구분할 수 있다', () {
      // 지금은 확정 일정(2026년 3회) 구간이어야 한다.
      expect(AppConfig.isExamDateConfirmed, isTrue,
          reason: '추정치를 확정인 것처럼 보여주면 유저를 오도한다');
    });
  });

  group('시험 당일 처리', () {
    test('남은 일수가 달력 기준으로 계산된다', () {
      // Duration.inDays 를 쓰면 전날 밤에 이미 0 이 되어 하루 밀린다.
      final exam = AppConfig.examDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expected =
          DateTime(exam.year, exam.month, exam.day).difference(today).inDays;
      expect(AppConfig.daysUntilExam, expected);
    });
  });
}
