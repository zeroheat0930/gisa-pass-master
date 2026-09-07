import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 무료 유저의 학습 플랜 초기화 횟수 제한 (하루 1회).
///
/// 초기화가 무제한이면 무료 구간만 있는 짧은 플랜을 리셋해 가며 영구 무료로
/// 쓸 수 있어, 긴 플랜의 유료 구간(Day 4+)을 살 이유가 사라진다. 플랜을
/// 잘못 골라 바꾸는 정상 사용은 하루 1회로 충분하므로, 그 이상만 프리미엄으로
/// 유도한다. 프리미엄은 무제한.
class PlanResetQuota {
  PlanResetQuota._();

  static const String _dateKey = 'plan_reset_quota_date';
  static const String _countKey = 'plan_reset_quota_count';

  /// 무료 유저의 하루 초기화 가능 횟수
  static const int freeResetsPerDay = 1;

  /// 로컬 날짜 키 (yyyy-MM-dd). 기기 시간대 기준.
  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 초기화 가능 여부. 프리미엄은 항상 true.
  static Future<bool> canReset({required bool isPremium}) async {
    if (isPremium) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dateKey) != _today()) return true; // 날짜가 바뀌면 초기화
      return (prefs.getInt(_countKey) ?? 0) < freeResetsPerDay;
    } catch (e) {
      debugPrint('플랜 초기화 쿼터 조회 실패: $e');
      return true; // 조회 실패로 유저를 막지 않는다
    }
  }

  /// 초기화 1회 소모. 프리미엄은 카운트하지 않는다.
  static Future<void> consume({required bool isPremium}) async {
    if (isPremium) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _today();
      if (prefs.getString(_dateKey) != today) {
        await prefs.setString(_dateKey, today);
        await prefs.setInt(_countKey, 0);
      }
      await prefs.setInt(_countKey, (prefs.getInt(_countKey) ?? 0) + 1);
    } catch (e) {
      debugPrint('플랜 초기화 쿼터 기록 실패: $e');
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dateKey);
    await prefs.remove(_countKey);
  }
}
