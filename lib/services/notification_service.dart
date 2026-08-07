import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config.dart';

/// 복습 알림.
///
/// 에빙하우스 망각곡선 반복 엔진(SpacedRepetitionService)은 이미 있었지만
/// **알려줄 수단이 없었다.** 복습 시기가 와도 유저가 앱을 직접 열어야만 알 수 있어서,
/// 공들여 만든 리텐션 엔진이 절반만 돌고 있었다.
///
/// 알림은 두 종류다.
///  - 복습 알림: 다음 복습 예정 시각에 1건 (오답노트가 쌓였을 때만)
///  - D-Day 알림: 시험 D-30 / D-7 / D-1 아침 9시
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// 알림 사용 여부 (유저가 끌 수 있다)
  static const String _prefsKeyEnabled = 'notifications_enabled';

  static const int _reviewId = 1001;
  static const int _ddayBaseId = 2000;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'study_reminder',
      '학습 알림',
      channelDescription: '복습 시기와 시험 D-Day를 알려줍니다',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// 앱 시작 시 1회 호출. 실패해도 앱 실행을 막지 않는다.
  static Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await _localTimezone()));

      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // 권한은 여기서 묻지 않는다. 첫 화면에서 권한 팝업이 쏟아지면
            // 그냥 거부당한다. 유저가 학습을 한 번 마친 뒤에 요청한다.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('알림 초기화 실패: $e');
    }
  }

  static Future<String> _localTimezone() async {
    // 이 앱은 국내 시험 대비용이라 KST 고정으로 충분하다.
    return 'Asia/Seoul';
  }

  /// 유저가 알림을 켜뒀는지
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKeyEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnabled, value);
    } catch (e) {
      debugPrint('알림 설정 저장 실패: $e');
    }
    if (!value) await cancelAll();
  }

  /// OS 알림 권한 요청. 이미 허용/거부된 상태면 그대로 반환한다.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    if (!_ready) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
    }
    return false;
  }

  /// 복습 알림 예약. [dueAt] 이 과거면 예약하지 않는다.
  ///
  /// 복습 대상이 여러 개여도 알림은 1건만 띄운다. 문제마다 알림을 보내면
  /// 알림 폭탄이 되어 유저가 알림 자체를 꺼버린다.
  static Future<void> scheduleReviewReminder({
    required DateTime dueAt,
    required int dueCount,
  }) async {
    if (kIsWeb || dueCount <= 0) return;
    if (!await isEnabled()) return;
    await initialize();
    if (!_ready) return;

    try {
      await _plugin.cancel(_reviewId);

      final when = tz.TZDateTime.from(dueAt, tz.local);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

      await _plugin.zonedSchedule(
        _reviewId,
        '복습할 시간이에요',
        '틀린 문제 $dueCount개가 기다리고 있어요. 지금 5분이면 끝나요.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('복습 알림 예약 실패: $e');
    }
  }

  /// 시험 D-30 / D-7 / D-1 알림을 아침 9시로 예약한다.
  static Future<void> scheduleExamCountdown() async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    await initialize();
    if (!_ready) return;

    const milestones = <int, String>{
      30: '시험까지 30일. 지금부터가 진짜입니다.',
      7: '시험까지 일주일. 오답노트부터 비우세요.',
      1: '내일이 시험입니다. 오늘은 족보만 훑으세요.',
    };

    try {
      final exam = AppConfig.examDate;
      for (final entry in milestones.entries) {
        final id = _ddayBaseId + entry.key;
        await _plugin.cancel(id);

        final day = exam.subtract(Duration(days: entry.key));
        final when = tz.TZDateTime(tz.local, day.year, day.month, day.day, 9);
        if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;

        await _plugin.zonedSchedule(
          id,
          'D-${entry.key}',
          entry.value,
          when,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('D-Day 알림 예약 실패: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('알림 취소 실패: $e');
    }
  }

  @visibleForTesting
  static Future<int> pendingCount() async {
    if (!_ready) return 0;
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }
}
