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

  /// 반환값이 true 면 지금 바로 응시할 수 있다(광고 보상 획득).
  static Future<bool> show(
    BuildContext context, {
    required bool isPremium,
    required VoidCallback onSeePremium,
  }) async {
    final canEarn = await AiExamQuota.canEarnBonus(isPremium: isPremium) &&
        (globalAdService?.shouldShowAds ?? false);

    if (canEarn) globalAdService?.loadRewardedAd();
    if (!context.mounted) return false;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConfig.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '오늘의 무료 모의고사 완료',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          canEarn
              ? '광고를 보면 지금 바로 1회 더 응시할 수 있어요.\n'
                  '프리미엄이면 광고 없이 무제한입니다.'
              : '무료로는 하루 ${AiExamQuota.freeAttemptsPerDay}회 응시할 수 있어요.\n'
                  '내일 다시 열리고, 프리미엄이면 지금 바로 무제한으로 볼 수 있습니다.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.5),
        ),
        actionsOverflowButtonSpacing: 6,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: Text('내일 다시', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'premium'),
            child: const Text('프리미엄',
                style: TextStyle(color: AppConfig.primaryColor)),
          ),
          if (canEarn)
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'ad'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('광고 보고 1회 더'),
            ),
        ],
      ),
    );

    if (choice == 'premium') {
      onSeePremium();
      return false;
    }
    if (choice != 'ad') return false;

    // 광고를 끝까지 본 경우에만 보상한다.
    final watched = await globalAdService?.showRewardedAd() ?? false;
    if (!watched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('광고를 끝까지 보셔야 1회가 지급돼요.'),
            backgroundColor: AppConfig.cardColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    }

    return AiExamQuota.grantBonus();
  }
}
