import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/widgets/dday_timer.dart';

/// 홈 D-Day 타이머는 **시험 시작 시각(09:30)** 을 겨냥한다.
///
/// 예전에는 '시험일 23:59:59' 기준이라 10/24 10:00 에 'D-1 13:59:59' 가 떴고,
/// 시험이 끝난 10/25 오후에도 시간이 흘렀으며, '시험 완료!' 분기는 자정에
/// 다음 회차로 먼저 넘어가 한 번도 보이지 않았다. 2026-3회는 10/25(일).
void main() {
  tearDown(() => AppConfig.nowForTest = null);

  DdayStatus statusAt(DateTime t) {
    AppConfig.nowForTest = () => t;
    return DdayStatus.at(AppConfig.now);
  }

  test('전제: 시험은 09:30 시작, 150분', () {
    final exam = DateTime(2026, 10, 25);
    expect(AppConfig.examStartOn(exam), DateTime(2026, 10, 25, 9, 30));
    expect(AppConfig.examEndOn(exam), DateTime(2026, 10, 25, 12));
  });

  test('10/24 10:00 → D-1, 시작까지 23:30:00', () {
    final s = statusAt(DateTime(2026, 10, 24, 10));
    expect(s.headline, 'D-1');
    expect(s.clock, '23:30:00', reason: '23시 59분 59초 기준이면 13:59:59 가 나왔다');
    expect(s.caption, '2026년 3회 | 10월 25일');
  });

  test('10/25 08:00 → D-DAY, 시작까지 01:30:00', () {
    final s = statusAt(DateTime(2026, 10, 25, 8));
    expect(s.headline, 'D-DAY');
    expect(s.clock, '01:30:00');
  });

  test('10/25 10:00 → 시험 진행 중 (시계 없음)', () {
    final s = statusAt(DateTime(2026, 10, 25, 10));
    expect(s.headline, '시험 진행 중');
    expect(s.clock, isNull);
  });

  test('10/25 15:00 → 수고하셨습니다 (시간이 더 흐르지 않는다)', () {
    final s = statusAt(DateTime(2026, 10, 25, 15));
    expect(s.headline, '수고하셨습니다!');
    expect(s.clock, isNull);
  });

  test('10/26 → 수고 인사 + 다음 시험 안내 (추정이면 예정)', () {
    final s = statusAt(DateTime(2026, 10, 26, 9));
    expect(s.headline, '수고하셨습니다!');
    expect(s.clock, isNull);
    expect(s.caption, '다음 시험 2027년 1회 (예정)');
  });

  test('10/28(3일째)까지 수고 인사, 10/29 부터는 평소 D-N(예정)', () {
    expect(statusAt(DateTime(2026, 10, 28, 23)).headline, '수고하셨습니다!');

    final s = statusAt(DateTime(2026, 10, 29, 9));
    expect(s.headline, startsWith('D-'));
    expect(s.headline, 'D-${AppConfig.daysUntilExam}');
    expect(s.clock, isNotNull);
    expect(s.caption, endsWith('(예정)'),
        reason: '2027년 일정은 미공고라 추정치다');
  });

  testWidgets('위젯이 같은 시계(AppConfig.now)로 D-N 과 시:분:초를 그린다',
      (tester) async {
    AppConfig.nowForTest = () => DateTime(2026, 10, 24, 10);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DdayTimer())),
    );
    expect(find.text('D-1'), findsOneWidget);
    expect(find.text('23:30:00'), findsOneWidget,
        reason: '시:분:초만 실제 시각을 보면 테스트 시각과 어긋난다');

    AppConfig.nowForTest = () => DateTime(2026, 10, 25, 15);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('수고하셨습니다!'), findsOneWidget);
    expect(find.text('23:30:00'), findsNothing);

    // 주기 타이머 정리
    await tester.pumpWidget(const SizedBox());
  });
}
