import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/plan_reset_quota.dart';
import 'package:gisa_pass_master/services/study_plan_service.dart';

/// 플랜 초기화가 무제한이면 무료 구간만 있는 짧은 플랜을 리셋해 가며
/// 영구 무료로 쓸 수 있었다(감사에서 '수익 직결'로 확정된 구멍).
/// 정상 사용(플랜 잘못 고름)은 하루 1회로 충분하다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('무료 유저', () {
    test('첫 초기화는 허용된다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await PlanResetQuota.canReset(isPremium: false), isTrue);
    });

    test('하루 한도를 쓰면 막힌다', () async {
      SharedPreferences.setMockInitialValues({});

      for (var i = 0; i < PlanResetQuota.freeResetsPerDay; i++) {
        expect(await PlanResetQuota.canReset(isPremium: false), isTrue);
        await PlanResetQuota.consume(isPremium: false);
      }

      expect(await PlanResetQuota.canReset(isPremium: false), isFalse,
          reason: '한도를 넘으면 막혀야 한다 — 무제한이면 영구 무료 경로가 열린다');
    });

    test('날짜가 바뀌면 다시 열린다', () async {
      SharedPreferences.setMockInitialValues({});
      await PlanResetQuota.consume(isPremium: false);
      expect(await PlanResetQuota.canReset(isPremium: false), isFalse);

      // 저장된 날짜를 과거로 돌려 '다음 날'을 재현
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plan_reset_quota_date', '2000-01-01');

      expect(await PlanResetQuota.canReset(isPremium: false), isTrue,
          reason: '날짜가 바뀌면 무료 초기화가 회복되어야 한다');
    });

    test('어제 쓴 횟수가 오늘로 이월되지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      await PlanResetQuota.consume(isPremium: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('plan_reset_quota_date', '2000-01-01');

      // 오늘 첫 소모 — 날짜가 오늘로 갱신되며 카운트가 0에서 다시 시작해야 한다
      await PlanResetQuota.consume(isPremium: false);

      expect(await PlanResetQuota.canReset(isPremium: false), isFalse,
          reason: '오늘 1회를 썼으면 막혀야 한다');
    });
  });

  group('프리미엄 유저', () {
    test('횟수 제한이 없다', () async {
      SharedPreferences.setMockInitialValues({});

      for (var i = 0; i < 10; i++) {
        expect(await PlanResetQuota.canReset(isPremium: true), isTrue);
        await PlanResetQuota.consume(isPremium: true);
      }

      expect(await PlanResetQuota.canReset(isPremium: true), isTrue);
    });

    test('프리미엄 초기화는 무료 한도를 깎지 않는다', () async {
      SharedPreferences.setMockInitialValues({});

      await PlanResetQuota.consume(isPremium: true);
      await PlanResetQuota.consume(isPremium: true);

      expect(await PlanResetQuota.canReset(isPremium: false), isTrue,
          reason: '프리미엄 초기화가 무료 카운트를 소모하면 안 된다');
    });
  });

  // 감사 확정 결함: 1일/3일 플랜이 전 구간 무료라 프리미엄 게이팅이 무력화됐다.
  // 규칙 — 무료는 짧은 플랜(1·3일) Day 1, 긴 플랜(5·7·14일) Day 3까지.
  group('플랜 프리미엄 게이팅', () {
    test('3일 플랜은 Day 2부터 프리미엄이다', () {
      expect(StudyPlanService.needsPremiumForDay('3day', 1), isFalse);
      expect(StudyPlanService.needsPremiumForDay('3day', 2), isTrue,
          reason: '전 구간 무료면 긴 플랜의 유료 구간을 살 이유가 없다');
      expect(StudyPlanService.needsPremiumForDay('3day', 3), isTrue);
    });

    test('1일 플랜은 Day 1 하나뿐이라 무료다', () {
      expect(StudyPlanService.needsPremiumForDay('1day', 1), isFalse);
    });

    test('긴 플랜은 Day 3까지 무료, Day 4부터 프리미엄이다', () {
      for (final planType in ['5day', '7day', '14day']) {
        expect(StudyPlanService.needsPremiumForDay(planType, 3), isFalse,
            reason: '$planType Day 3은 무료여야 한다');
        expect(StudyPlanService.needsPremiumForDay(planType, 4), isTrue,
            reason: '$planType Day 4는 프리미엄이어야 한다');
      }
    });

    test('모르는 플랜 타입은 긴 플랜 규칙을 따른다', () {
      expect(StudyPlanService.needsPremiumForDay('30day', 3), isFalse);
      expect(StudyPlanService.needsPremiumForDay('30day', 4), isTrue);
    });
  });
}
