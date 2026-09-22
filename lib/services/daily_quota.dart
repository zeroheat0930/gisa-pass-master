import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기 로컬 날짜가 바뀌면 함께 0 으로 돌아가는 카운터 묶음.
///
/// AiExamQuota(모의고사 응시·광고 보너스)와 PlanResetQuota(플랜 초기화)가 각자
/// 날짜 키·롤오버·소모 로직을 복붙해 갖고 있었다. 롤오버 규칙을 한쪽만 고치면
/// 다른 쪽이 어긋나므로 정본을 하나로 둔다.
///
/// [counterKeys] 는 **한 날짜를 공유**한다. 예전에 AiExamQuota 의 consume 과
/// grantBonus 가 각자 날짜를 갱신하면서 자기 카운터만 리셋해, 어제 광고로 얻은
/// 보너스가 오늘 무료 1회를 쓰는 순간 오늘 것으로 둔갑했다(광고 없이 응시권이
/// 생기는 경로). 날짜가 바뀌면 모든 카운터를 같이 0 으로 돌린다.
class DailyQuota {
  const DailyQuota({
    required this.label,
    required this.dateKey,
    required this.counterKeys,
  });

  /// 로그용 이름
  final String label;

  /// 마지막으로 기록한 날짜(yyyy-MM-dd)를 담는 키
  final String dateKey;

  /// 날짜와 함께 초기화되는 카운터 키들
  final List<String> counterKeys;

  /// 로컬 날짜 키 (yyyy-MM-dd). 기기 시간대 기준.
  static String today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// 오늘 [key] 의 값. 날짜가 바뀌었으면 0.
  /// 조회 실패도 0 — 조회 실패로 유저를 막지 않는다.
  Future<int> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(dateKey) != today()) return 0;
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('$label 조회 실패: $e');
      return 0;
    }
  }

  /// [key] 를 1 올린다. [limit] 이 있고 이미 그만큼이면 올리지 않고 false.
  /// 기록 실패도 false.
  ///
  /// 날짜가 바뀐 첫 기록이면 오늘 날짜를 찍고 나머지 카운터를 0 으로 돌린 뒤
  /// [key] 는 곧바로 1 로 쓴다(0 을 썼다가 다시 1 을 쓰지 않는다).
  Future<bool> increment(String key, {int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DailyQuota.today();
      final isNewDay = prefs.getString(dateKey) != today;
      final current = isNewDay ? 0 : (prefs.getInt(key) ?? 0);
      if (limit != null && current >= limit) return false;
      if (isNewDay) {
        await prefs.setString(dateKey, today);
        for (final other in counterKeys) {
          if (other != key) await prefs.setInt(other, 0);
        }
      }
      await prefs.setInt(key, current + 1);
      return true;
    } catch (e) {
      debugPrint('$label 기록 실패: $e');
      return false;
    }
  }

  /// 날짜와 카운터를 모두 지운다. 각 쿼터의 resetForTest 가 쓴다.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(dateKey);
    for (final key in counterKeys) {
      await prefs.remove(key);
    }
  }
}
