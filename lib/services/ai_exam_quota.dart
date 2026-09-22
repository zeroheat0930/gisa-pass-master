import 'package:flutter/foundation.dart';

import 'daily_quota.dart';

/// 무료 유저의 AI 실전 모의고사 응시 횟수 제한 (하루 N회).
///
/// 구독 화면은 AI 모의고사를 유료 전용으로 광고하는데 코드에는 게이트가 전혀 없어서,
/// 무료 유저가 무제한으로 쓰고 있었다. 결제한 유저 입장에서는 산 보람이 없는 상태.
///
/// 완전히 막으면 지금까지 쓰던 무료 유저에게서 기능을 빼앗는 것이라, 하루 1회는
/// 열어두고 그 이상만 프리미엄으로 유도한다. 모의고사는 중간에 자르면 경험이 깨지므로
/// 문항 수가 아니라 **응시 횟수**로 제한한다.
///
/// 날짜별 카운터의 정본은 [DailyQuota]. 응시 횟수와 광고 보너스가 한 날짜를
/// 공유해야 하는 이유도 거기에 적혀 있다.
class AiExamQuota {
  AiExamQuota._();

  static const String _countKey = 'ai_exam_quota_count';

  /// 오늘 광고로 얻은 보너스 응시 횟수를 담는 키
  static const String _bonusKey = 'ai_exam_bonus_count';

  static const DailyQuota _quota = DailyQuota(
    label: '모의고사 쿼터',
    dateKey: 'ai_exam_quota_date',
    counterKeys: [_countKey, _bonusKey],
  );

  /// 무료 유저의 하루 응시 가능 횟수
  static const int freeAttemptsPerDay = 1;

  /// 광고 시청 보상으로 1회 추가. 하루에 얻을 수 있는 보너스에도 상한을 둔다
  /// (무제한이면 프리미엄을 살 이유가 사라진다).
  static const int maxBonusPerDay = 2;

  /// 오늘 이미 사용한 횟수
  static Future<int> usedToday() => _quota.read(_countKey);

  /// 오늘 광고로 얻은 보너스 응시 횟수
  static Future<int> bonusToday() => _quota.read(_bonusKey);

  /// 남은 무료 응시 횟수 (프리미엄은 무제한이므로 사용처에서 먼저 걸러낼 것)
  static Future<int> remainingToday() async {
    final used = await usedToday();
    final left = freeAttemptsPerDay + await bonusToday() - used;
    return left < 0 ? 0 : left;
  }

  /// 광고 보상 1회 지급. 오늘 상한에 닿았으면 false.
  static Future<bool> grantBonus() =>
      _quota.increment(_bonusKey, limit: maxBonusPerDay);

  /// 광고로 응시권을 더 얻을 수 있는 상태인지
  static Future<bool> canEarnBonus({required bool isPremium}) async {
    if (isPremium) return false;
    return await bonusToday() < maxBonusPerDay;
  }

  /// 응시 가능 여부. 프리미엄은 항상 true.
  static Future<bool> canStart({required bool isPremium}) async {
    if (isPremium) return true;
    final allowed = freeAttemptsPerDay + await bonusToday();
    return await usedToday() < allowed;
  }

  /// 응시 1회 소모. 프리미엄은 카운트하지 않는다.
  static Future<void> consume({required bool isPremium}) async {
    if (isPremium) return;
    await _quota.increment(_countKey);
  }

  @visibleForTesting
  static Future<void> resetForTest() => _quota.clear();
}
