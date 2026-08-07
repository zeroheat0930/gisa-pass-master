import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 무료 유저의 AI 실전 모의고사 응시 횟수 제한 (하루 N회).
///
/// 구독 화면은 AI 모의고사를 유료 전용으로 광고하는데 코드에는 게이트가 전혀 없어서,
/// 무료 유저가 무제한으로 쓰고 있었다. 결제한 유저 입장에서는 산 보람이 없는 상태.
///
/// 완전히 막으면 지금까지 쓰던 무료 유저에게서 기능을 빼앗는 것이라, 하루 1회는
/// 열어두고 그 이상만 프리미엄으로 유도한다. 모의고사는 중간에 자르면 경험이 깨지므로
/// 문항 수가 아니라 **응시 횟수**로 제한한다.
class AiExamQuota {
  AiExamQuota._();

  static const String _dateKey = 'ai_exam_quota_date';
  static const String _countKey = 'ai_exam_quota_count';

  /// 무료 유저의 하루 응시 가능 횟수
  static const int freeAttemptsPerDay = 1;

  /// 로컬 날짜 키 (yyyy-MM-dd). 기기 시간대 기준.
  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 오늘 이미 사용한 횟수
  static Future<int> usedToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dateKey) != _today()) return 0; // 날짜가 바뀌면 초기화
      return prefs.getInt(_countKey) ?? 0;
    } catch (e) {
      debugPrint('모의고사 쿼터 조회 실패: $e');
      return 0; // 조회 실패로 유저를 막지 않는다
    }
  }

  /// 남은 무료 응시 횟수 (프리미엄은 무제한이므로 사용처에서 먼저 걸러낼 것)
  static Future<int> remainingToday() async {
    final used = await usedToday();
    final left = freeAttemptsPerDay + await bonusToday() - used;
    return left < 0 ? 0 : left;
  }

  /// 오늘 광고로 얻은 보너스 응시 횟수
  static const String _bonusKey = 'ai_exam_bonus_count';

  static Future<int> bonusToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dateKey) != _today()) return 0;
      return prefs.getInt(_bonusKey) ?? 0;
    } catch (e) {
      debugPrint('보너스 조회 실패: $e');
      return 0;
    }
  }

  /// 광고 시청 보상으로 1회 추가. 하루에 얻을 수 있는 보너스에도 상한을 둔다
  /// (무제한이면 프리미엄을 살 이유가 사라진다).
  static const int maxBonusPerDay = 2;

  static Future<bool> grantBonus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      final current = prefs.getString(_dateKey) == today
          ? (prefs.getInt(_bonusKey) ?? 0)
          : 0;
      if (current >= maxBonusPerDay) return false;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_bonusKey, current + 1);
      return true;
    } catch (e) {
      debugPrint('보너스 지급 실패: $e');
      return false;
    }
  }

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      final count = prefs.getString(_dateKey) == today
          ? (prefs.getInt(_countKey) ?? 0)
          : 0;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, count + 1);
    } catch (e) {
      debugPrint('모의고사 쿼터 기록 실패: $e');
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateKey);
    await prefs.remove(_countKey);
    await prefs.remove(_bonusKey);
  }
}
