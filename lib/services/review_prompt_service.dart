import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스토어 리뷰 요청의 단일 정본.
///
/// 평생권이라 재구매가 없다 — 리뷰 수와 랭킹이 사실상 유일한 증폭 수단인데,
/// 지금까지는 요청 API 자체가 없었다(홈 화면의 텍스트 부탁 한 줄이 전부).
///
/// **언제 묻지 않는가가 더 중요하다.** 시스템 리뷰 다이얼로그는 1년에 노출
/// 횟수가 제한되어 있어 한 번 헛되이 쓰면 그 유저에게는 오래 못 묻는다.
///  - 세션 정답률이 합격선(60%) 미만이면 묻지 않는다. 낮은 점수 직후의 요청은
///    별점을 깎는다.
///  - 누적 [minCumulativeSolved] 문항 미만이면 묻지 않는다. 앱을 써보지도 않은
///    사람에게 묻는 꼴이다.
///  - 마지막 요청 후 [cooldownDays] 일이 지나지 않았으면 묻지 않는다.
class ReviewPromptService {
  ReviewPromptService._();

  /// 마지막으로 리뷰를 요청한 시각 (ISO-8601). **이 서비스 전용 키다.**
  ///
  /// `DailyQuota` 를 재사용하지 않는 이유: 그쪽은 '날짜가 바뀌면 리셋'이고
  /// 여기는 '90일 쿨다운'이라 리셋의 의미가 다르다. 섞으면 둘 다 깨진다 —
  /// 모의고사 쿼터가 90일간 안 풀리거나, 리뷰를 매일 묻게 된다.
  static const String lastRequestedKey = 'review_prompt_last_requested_at';

  /// 누적으로 푼 문항 수 (이 서비스 전용 카운터).
  ///
  /// 통계 DB 를 읽지 않는다. 호출부인 결과 화면은 `DatabaseService` 를 들고
  /// 있지 않고, 여기서 provider 를 끌어오면 풀이 화면의 의존성만 늘어난다.
  /// 리뷰 요청 조건에는 '대략 이만큼 써봤다'는 값이면 충분하다.
  ///
  /// **앱 전체 누적이 아니라 이 서비스가 들어온 뒤의 누적이다.** 이미 수천 문항을
  /// 푼 기존 유저도 업데이트 후 [minCumulativeSolved] 문항을 새로 풀어야 첫 요청을
  /// 받는다. 의도한 동작이다 — 과거 기록으로 업데이트 직후 곧바로 묻는 것보다,
  /// 새 버전을 써본 뒤에 묻는 편이 별점에 유리하다.
  static const String solvedTotalKey = 'review_prompt_solved_total';

  /// 합격선. 이 밑에서는 묻지 않는다.
  static const int minCorrectPercent = 60;

  /// 누적 풀이 문항 하한
  static const int minCumulativeSolved = 30;

  /// 재요청 쿨다운
  static const int cooldownDays = 90;

  /// 지금 리뷰를 물어도 되는지 — 순수 함수(저장소·플랫폼을 건드리지 않는다).
  static bool shouldRequest({
    required int sessionTotal,
    required int sessionCorrect,
    required int cumulativeSolved,
    DateTime? lastRequestedAt,
    DateTime? now,
  }) {
    if (sessionTotal <= 0) return false;
    // 정수로 비교한다. 0.59 같은 부동소수 반올림으로 경계가 흔들리면
    // "59% 인데 물었다"는 사고가 재현 불가능해진다.
    if (sessionCorrect * 100 < sessionTotal * minCorrectPercent) return false;
    if (cumulativeSolved < minCumulativeSolved) return false;
    if (lastRequestedAt == null) return true;
    return (now ?? DateTime.now()).difference(lastRequestedAt).inDays >=
        cooldownDays;
  }

  /// 세션 결과를 누적에 반영하고, 조건을 만족하면 스토어 리뷰를 요청한다.
  ///
  /// 반환값 true 는 **실제로 요청이 나갔다**는 뜻이다. 조건 미달이거나 스토어가
  /// 다이얼로그를 띄울 수 없는 상태면 false 이고, 그때는 쿨다운도 태우지 않는다.
  ///
  /// [isCancelled] 는 저장소를 읽는 사이에 유저가 다른 흐름으로 들어갔는지를
  /// 묻는다(결과 화면의 유료 CTA → 쿼터 소진 다이얼로그). 다이얼로그가 겹치면
  /// 둘 다 무시당하고 별점만 깎이므로, 그때는 요청하지 않는다.
  static Future<bool> requestIfEligible({
    required int sessionTotal,
    required int sessionCorrect,
    bool Function()? isCancelled,
    DateTime? now,
  }) async {
    // 리뷰 요청은 부가 기능이다. 호출부가 `unawaited` 로 띄우므로 여기서 예외가
    // 새면 미처리 비동기 예외가 되어 결과 화면 흐름까지 같이 죽는다.
    // 플랫폼 채널이 없거나(MissingPluginException) 스토어가 거부하는
    // (PlatformException) 경우는 정상 동작 범위이므로 조용히 false 로 끝낸다.
    try {
      final prefs = await SharedPreferences.getInstance();

      final cumulative = (prefs.getInt(solvedTotalKey) ?? 0) +
          (sessionTotal < 0 ? 0 : sessionTotal);
      await prefs.setInt(solvedTotalKey, cumulative);

      final rawLast = prefs.getString(lastRequestedKey);
      final lastRequestedAt =
          rawLast == null ? null : DateTime.tryParse(rawLast);
      final at = now ?? DateTime.now();

      if (!shouldRequest(
        sessionTotal: sessionTotal,
        sessionCorrect: sessionCorrect,
        cumulativeSolved: cumulative,
        lastRequestedAt: lastRequestedAt,
        now: at,
      )) {
        return false;
      }

      final before = beforeOpenForTest;
      if (before != null) await before();

      if (isCancelled?.call() ?? false) return false;

      // 스토어가 못 띄웠는데 시각을 기록하면 90일을 그냥 버린다.
      if (!await _openStoreReview(isCancelled)) return false;
      await prefs.setString(lastRequestedKey, at.toIso8601String());
      return true;
    } catch (e) {
      debugPrint('ReviewPromptService.requestIfEligible 실패: $e');
      return false;
    }
  }

  /// 테스트용 시임. 위젯 테스트에서 플랫폼 채널을 타지 않게 갈아끼운다.
  @visibleForTesting
  static Future<bool> Function()? debugOpenStoreReview;

  /// 테스트용 시임. [isCancelled] 검사 **직전**에 await 된다.
  ///
  /// 실제 기기에서는 저장소 I/O 가 "평가 중 유저가 CTA 를 탭한다"는 창을 만들지만,
  /// 위젯 테스트의 prefs 는 메모리라 결과 화면이 그려지기도 전에 평가가 끝나버려
  /// 그 경합을 재현할 수 없다. 이 시임이 그 창을 테스트가 열어준다.
  @visibleForTesting
  static Future<void> Function()? beforeOpenForTest;

  /// 스토어 기본 리뷰 다이얼로그. **자체 별점 위젯을 만들지 않는다** —
  /// 앱이 직접 별점을 받아 스토어로 유도하는 것은 애플·구글 정책 위반이다.
  static Future<bool> _openStoreReview(bool Function()? isCancelled) async {
    final override = debugOpenStoreReview;
    if (override != null) return override();

    final review = InAppReview.instance;
    if (!await review.isAvailable()) return false;
    // isAvailable 이 플랫폼 왕복이라 그 사이에도 CTA 가 눌릴 수 있다.
    if (isCancelled?.call() ?? false) return false;
    await review.requestReview();
    return true;
  }
}
