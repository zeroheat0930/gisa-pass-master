import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';

/// 탭하면 메일 주소를 클립보드에 복사하는 줄.
///
/// 이 줄은 홈의 개발자 카드 안에 있는데, **그 카드 전체가 구독 화면으로 가는
/// 탭이다.** 안쪽 GestureDetector 가 탭을 먼저 받으므로 메일을 누르려다
/// 결제 화면으로 끌려가지 않는다.
///
/// url_launcher 로 메일 앱을 여는 대신 복사만 한다 — 메일 하나 때문에 의존성을
/// 늘릴 이유가 없고, 주소를 복사해두면 어느 메일 앱에서든 쓸 수 있다.
class CopyEmailRow extends StatelessWidget {
  final String email;

  const CopyEmailRow({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: email));
        if (!context.mounted) return;
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메일 주소를 복사했어요 · $email'),
            backgroundColor: AppConfig.cardColor,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          const Icon(Icons.mail_outline, color: Color(0xFF2196F3), size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              email,
              style: const TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '탭하면 복사',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
