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

    // 다이얼로그를 실제로 보여준 뒤에 '물어봤음' 을 기록한다.
    // 표시 전에 기록하면 화면 전환 등으로 다이얼로그가 삼켜졌을 때
    // 유저는 보지도 못한 채 알림 제안 기회가 영영 사라진다.
    await _markAsked();

    if (accepted != true) return;

    final granted = await NotificationService.requestPermission();
    await NotificationService.setEnabled(granted);
    if (!granted) return;

    // 수락 직후 **복습 알림까지** 잡는다. D-Day 만 잡으면 다이얼로그가 약속한
    // "복습 시간이 되면 알려드릴게요" 가 앱을 재시작하기 전까지 지켜지지 않는다.
    await NotificationService.scheduleExamCountdown();
    await onEnabled?.call();
  }

  /// 알림을 켠 직후 실행할 후속 작업(복습 알림 재예약).
  /// 호출부가 SpacedRepetitionService 를 갖고 있으므로 콜백으로 받는다.
  static Future<void> Function()? onEnabled;
}
