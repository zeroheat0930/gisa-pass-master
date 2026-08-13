// 화면을 눈으로 확인하기 위한 개발 전용 진입점. 앱 빌드에는 포함되지 않는다.
//   flutter run -d macos -t tool/preview_main.dart
import 'package:flutter/material.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/screens/pass_rate_screen.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppConfig.backgroundColor,
      ),
      // 실제 휴대폰 폭으로 좁혀서 본다.
      home: Center(
        child: SizedBox(width: 390, child: const PassRateScreen()),
      ),
    );
  }
}
