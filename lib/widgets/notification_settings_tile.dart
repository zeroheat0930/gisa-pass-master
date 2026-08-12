import 'package:flutter/material.dart';

import '../config.dart';
import '../services/notification_service.dart';

/// 알림 켜기/끄기 (통계 화면에 배치).
///
/// 이게 없으면 옵트인 다이얼로그에서 '나중에' 를 한 번 누른 유저는
/// **앱 안에서 알림을 다시 켤 방법이 영원히 없다.**
class NotificationSettingsTile extends StatefulWidget {
  /// 알림을 켠 뒤 복습 알림을 다시 잡기 위한 콜백
  final Future<void> Function()? onEnabled;

  const NotificationSettingsTile({super.key, this.onEnabled});

  @override
  State<NotificationSettingsTile> createState() =>
      _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await NotificationService.isEnabled();
    if (!mounted) return;
    setState(() => _enabled = on);
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (!value) {
        await NotificationService.setEnabled(false);
        if (!mounted) return;
        setState(() => _enabled = false);
        return;
      }

      final granted = await NotificationService.requestPermission();
      await NotificationService.setEnabled(granted);
      if (!mounted) return;
      setState(() => _enabled = granted);

      if (granted) {
        await NotificationService.scheduleExamCountdown();
        await widget.onEnabled?.call();
      } else if (mounted) {
        // OS 에서 거부된 상태면 앱 토글만으로는 켤 수 없다. 유저에게 알려준다.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('기기 설정에서 이 앱의 알림을 허용해주세요.'),
            backgroundColor: AppConfig.cardColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 배경을 Container 의 decoration 이 아니라 Material 이 칠한다.
    // 사이에 배경색을 가진 DecoratedBox 가 끼면 SwitchListTile 의 잉크 스플래시가
    // 그 아래에 그려져 **터치 피드백이 보이지 않는다** (Flutter 3.44 가 이를
    // 어서션으로 잡아낸다). 테두리는 Material 의 shape 로 옮긴다.
    return Material(
      color: AppConfig.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppConfig.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _busy ? null : _toggle,
          activeThumbColor: AppConfig.primaryColor,
          title: const Text(
            '복습 알림',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '복습 시기와 시험 D-30 / D-7 / D-1 을 알려드려요',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ),
    );
  }
}
