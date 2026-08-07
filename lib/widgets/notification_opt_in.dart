import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../services/notification_service.dart';

/// 복습 알림 켜기 제안.
///
/// 앱 첫 실행에 권한 팝업을 띄우면 대부분 거부한다. 유저가 학습을 한 번 마쳐서
/// "틀린 문제가 쌓였다"는 맥락이 생겼을 때 물어야 수락률이 높다.
/// 한 번 제안하고 나면 다시 묻지 않는다(거부한 유저를 계속 괴롭히지 않는다).
class NotificationOptIn {
  NotificationOptIn._();

  static const String _prefsKeyAsked = 'notification_opt_in_asked';

  static Future<bool> _alreadyAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKeyAsked) ?? false;
    } catch (_) {
      return true; // 조회 실패 시 묻지 않는다
    }
  }

  static Future<void> _markAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAsked, true);
    } catch (_) {}
  }

  /// 조건이 맞을 때만 제안한다. [wrongCount] 가 0이면 제안하지 않는다
  /// (복습할 게 없는데 알림을 권하면 설득력이 없다).
  static Future<void> maybeAsk(BuildContext context,
      {required int wrongCount}) async {
    if (wrongCount <= 0) return;
    if (await _alreadyAsked()) return;
    if (await NotificationService.isEnabled()) return;
    if (!context.mounted) return;

    await _markAsked();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConfig.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppConfig.primaryColor),
            SizedBox(width: 10),
            Expanded(
              child: Text('복습 알림 받을까요?',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Text(
          '틀린 문제 $wrongCount개가 오답노트에 들어갔어요.\n\n'
          '망각곡선에 맞춰 다시 볼 시간이 되면 알려드릴게요. '
          '이 타이밍을 놓치면 그냥 잊어버립니다.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('나중에', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor),
            child: const Text('알림 받기'),
          ),
        ],
      ),
    );

    if (accepted != true) return;

    final granted = await NotificationService.requestPermission();
    await NotificationService.setEnabled(granted);
    if (granted) {
      await NotificationService.scheduleExamCountdown();
    }
  }
}
