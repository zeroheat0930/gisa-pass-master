import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/ad_service.dart';
import '../services/ai_exam_quota.dart';

/// 오늘 무료 응시를 다 쓴 유저에게 보여주는 안내 (단일 정본).
///
/// 세 갈래를 준다.
///  - 광고 보고 1회 더 (하루 [AiExamQuota.maxBonusPerDay] 회까지)
///  - 프리미엄 (무제한)
///  - 내일 다시
///
/// 광고 선택지를 두는 이유는 두 가지다. 새 수익원이 되고, 무료 유저가
/// 유료 기능을 체험하게 되어 구매로 이어지는 통로가 된다.
/// 보너스에도 상한을 두는 이유는 무제한이면 프리미엄을 살 이유가 사라지기 때문이다.
class ExamQuotaDialog {
  ExamQuotaDialog._();

  /// 유료 벽에 닿은 유저에게 주는 **사실 서술** 한 줄.
  ///
  /// "지금 안 사면" 류의 압박 문구는 쓰지 않는다. 결제 화면 카피와 실제
  /// 게이팅이 어긋나면 환불·심사 분쟁이 되므로, 숫자는 전부 정본에서 읽는다.
  /// D-Day 꼬리표는 조립까지 [AppConfig.examCountdownSuffix] 가 끝낸 것을 붙이기만
  /// 한다 — 여기서 다시 조립하면 구독 화면과 두 벌이 되어 한쪽만 고쳐진다.
  static String _factLine() =>
      '무료는 하루 ${AiExamQuota.freeAttemptsPerDay}회'
      '${AppConfig.examCountdownSuffix}';

  /// 반환값이 true 면 지금 바로 응시할 수 있다(광고 보상 획득).
  ///
  /// [onSeePremium] 이 Future 를 돌려주면(구독 화면 push 등) **그게 끝날 때까지**
  /// 기다렸다가 반환한다. 호출부는 반환 뒤 프리미엄 여부를 다시 보고 곧장 응시로
  /// 이어갈 수 있다 — 기다리지 않으면 결제를 마치고 돌아와도 모의고사가 시작되지
  /// 않아, 방금 돈을 낸 유저가 버튼을 다시 찾아 눌러야 한다.
  static Future<bool> show(
    BuildContext context, {
    required bool isPremium,
    required FutureOr<void> Function() onSeePremium,
  }) async {
    final canEarn =
        await AiExamQuota.canEarnBonus(isPremium: isPremium) &&
        (globalAdService?.shouldShowAds ?? false);

    if (canEarn) globalAdService?.loadRewardedAd();
    if (!context.mounted) return false;

    // '광고 준비 중...' 라벨을 로드 완료 시점에 갱신하기 위한 폴링.
    // AdService 는 ChangeNotifier 가 아니라 빌드 시점 판정이 그대로 굳는데,
    // 로드가 끝나도 라벨이 안 바뀌면 유저가 '안 되는구나' 하고 이탈한다.
    Timer? readyPoll;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (canEarn && !(globalAdService?.isRewardedReady ?? false)) {
            readyPoll ??= Timer.periodic(const Duration(milliseconds: 500), (
              t,
            ) {
              if (globalAdService?.isRewardedReady ?? false) {
                t.cancel();
                setDialogState(() {});
                return;
              }
              // 첫 로드가 no-fill 로 실패하면 아무도 다시 로드하지 않아
              // '광고 준비 중...'이 영구히 남는다. 2초마다 재요청한다
              // (AdService 가 로드 중이면 중복 요청을 무시한다).
              if (t.tick % 4 == 0) globalAdService?.loadRewardedAd();
            });
          }
          return AlertDialog(
            backgroundColor: AppConfig.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '오늘의 무료 모의고사 완료',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '${_factLine()}\n'
              '${canEarn ? '광고를 보면 지금 바로 1회 더 응시할 수 있어요.\n프리미엄이면 광고 없이 무제한입니다.' : '내일 다시 열리고, 프리미엄이면 지금 바로 무제한으로 볼 수 있습니다.'}',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actionsOverflowButtonSpacing: 6,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'later'),
                child: Text('내일 다시', style: TextStyle(color: Colors.grey[400])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'premium'),
                child: const Text(
                  '프리미엄',
                  style: TextStyle(color: AppConfig.primaryColor),
                ),
              ),
              if (canEarn)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'ad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                  ),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(
                    (globalAdService?.isRewardedReady ?? false)
                        ? '광고 보고 1회 더'
                        : '광고 준비 중...',
                  ),
                ),
            ],
          );
        },
      ),
    );
    readyPoll?.cancel();

    if (choice == 'premium') {
      await onSeePremium();
      return false;
    }
    if (choice != 'ad') return false;

    // 광고가 아직 준비되지 않았으면 유저 탓을 하지 않는다.
    // "끝까지 보셔야" 라고 안내하면 보지도 못한 유저가 자기가 잘못한 줄 안다.
    final ready = globalAdService?.isRewardedReady ?? false;
    if (!ready) {
      globalAdService?.loadRewardedAd();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('광고를 불러오는 중이에요. 잠시 후 다시 눌러주세요.'),
            backgroundColor: AppConfig.cardColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return false;
    }

    // 광고를 끝까지 본 경우에만 보상한다.
    // 뜨지 못한 것과 중간에 닫은 것은 안내를 나눈다. 둘을 한 문구로 묶으면
    // 광고를 보지도 못한 유저에게 "끝까지 보셔야" 라고 유저 탓을 하게 된다.
    final result =
        await globalAdService?.showRewardedAd() ??
        RewardedAdResult.failedToShow;
    switch (result) {
      case RewardedAdResult.failedToShow:
        if (context.mounted) {
          _snack(context, '광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
        }
        return false;
      case RewardedAdResult.dismissedEarly:
        if (context.mounted) _snack(context, '광고를 끝까지 보셔야 1회가 지급돼요.');
        return false;
      case RewardedAdResult.earned:
        break;
    }

    // 광고를 다 봤는데 저장이 실패하면 조용히 끝내지 않는다. 유저는 광고를 본
    // 대가를 못 받은 채 이유도 모르고 버튼만 다시 누르게 된다.
    final granted = await AiExamQuota.grantBonus();
    if (!granted && context.mounted) {
      _snack(context, '보너스 저장에 실패했어요. 다시 시도해주세요.');
    }
    return granted;
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConfig.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
