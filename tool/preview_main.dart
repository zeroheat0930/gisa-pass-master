// 복원 기출 문항이 실제 폰트로 어떻게 보이는지 눈으로 확인하기 위한 임시 진입점.
// 앱 코드에는 영향이 없다. 실행:
//   flutter run -d macos -t tool/preview_main.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/widgets/question_card.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _PreviewPage(),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  const _PreviewPage();

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  List<Question> _tableQuestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle
        .loadString('assets/questions/restored_exam_questions.json');
    final items = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    final qs = items
        .where((e) => (e['questionText'] as String)
            .split('\n')
            .any((l) => l.split('|').length >= 3))
        .map((e) => Question(
              year: e['year'] as int,
              round: e['round'] as int,
              subject: e['subject'] as String,
              questionType: e['questionType'] as String,
              questionText: e['questionText'] as String,
              codeSnippet: e['codeSnippet'] as String?,
              codeLanguage: e['codeLanguage'] as String?,
              answer: e['answer'] as String,
              explanation: e['explanation'] as String? ?? '',
              source: e['source'] as String? ?? Question.sourceAi,
            ))
        .toList();
    setState(() => _tableQuestions = qs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text('표 문항 미리보기 (${_tableQuestions.length}개)')),
      // 실제 휴대폰 폭에 가깝게 좁혀서 본다.
      body: Center(
        child: SizedBox(
          width: 390,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _tableQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (_, i) => QuestionCard(question: _tableQuestions[i]),
          ),
        ),
      ),
    );
  }
}
