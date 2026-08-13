// 화면을 눈으로 확인하기 위한 개발 전용 진입점. 앱 빌드에는 포함되지 않는다.
//   flutter run -d macos -t tool/preview_main.dart
import 'package:flutter/material.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/widgets/answer_input_field.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();
  @override
  State<_PreviewApp> createState() => _S();
}

class _S extends State<_PreviewApp> {
  final a = TextEditingController();
  final b = TextEditingController();
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppConfig.backgroundColor),
      home: Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        body: Center(
          child: SizedBox(
            width: 390,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('답 3개 (번호 라벨)',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                AnswerInputField(
                    controller: a,
                    correctAnswer: '1. 문장\n2. 분기\n3. 조건',
                    onSubmit: () {}),
                const SizedBox(height: 28),
                const Text('답 5개 (ㄱㄴㄷ 라벨)',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                AnswerInputField(
                    controller: b,
                    correctAnswer:
                        'ㄱ. 요구사항 분석\nㄴ. 개념적 설계\nㄷ. 논리적 설계\nㄹ. 물리적 설계\nㅁ. 구현',
                    onSubmit: () {}),
                const SizedBox(height: 28),
                const Text('여러 줄 출력 (칸 하나 유지)',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                AnswerInputField(
                    controller: c, correctAnswer: '3\n1', onSubmit: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
