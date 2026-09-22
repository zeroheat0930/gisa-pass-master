import 'package:flutter/foundation.dart';

import 'daily_quota.dart';

/// 무료 유저의 학습 플랜 초기화 횟수 제한 (하루 1회).
///
/// 초기화가 무제한이면 무료 구간만 있는 짧은 플랜을 리셋해 가며 영구 무료로
/// 쓸 수 있어, 긴 플랜의 유료 구간(Day 4+)을 살 이유가 사라진다. 플랜을
/// 잘못 골라 바꾸는 정상 사용은 하루 1회로 충분하므로, 그 이상만 프리미엄으로
/// 유도한다. 프리미엄은 무제한.
///
/// 날짜별 카운터의 정본은 [DailyQuota] (AiExamQuota 와 같은 방식).
class PlanResetQuota {
  PlanResetQuota._();

  static const String _countKey = 'plan_reset_quota_count';

  static const DailyQuota _quota = DailyQuota(
    label: '플랜 초기화 쿼터',
    dateKey: 'plan_reset_quota_date',
    counterKeys: [_countKey],
  );

  /// 무료 유저의 하루 초기화 가능 횟수
  static const int freeResetsPerDay = 1;

  /// 초기화 가능 여부. 프리미엄은 항상 true.
  static Future<bool> canReset({required bool isPremium}) async {
    if (isPremium) return true;
    return await _quota.read(_countKey) < freeResetsPerDay;
  }

  /// 초기화 1회 소모. 프리미엄은 카운트하지 않는다.
  static Future<void> consume({required bool isPremium}) async {
    if (isPremium) return;
    await _quota.increment(_countKey);
  }

  @visibleForTesting
  static Future<void> resetForTest() => _quota.clear();
}
