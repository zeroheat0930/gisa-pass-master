import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/question.dart';

class QuestionSeedData {
  static List<Question>? _cached;

  /// JSON 에셋에서 전체 문제 로드 (캐싱)
  static Future<List<Question>> loadAll() async {
    if (_cached != null) return _cached!;

    final files = [
      'assets/questions/c_questions.json',
      'assets/questions/java_questions.json',
      'assets/questions/python_questions.json',
      'assets/questions/sql_questions.json',
      'assets/questions/short_answer_questions.json',
    ];

    final allQuestions = <Question>[];

    for (final file in files) {
      try {
        final jsonStr = await rootBundle.loadString(file);
        final List<dynamic> jsonList = json.decode(jsonStr);
        for (final item in jsonList) {
          allQuestions.add(Question(
            year: item['year'] as int,
            round: item['round'] as int,
            subject: item['subject'] as String,
            questionType: item['questionType'] as String,
            questionText: item['questionText'] as String,
            codeSnippet: item['codeSnippet'] as String?,
            codeLanguage: item['codeLanguage'] as String?,
            answer: item['answer'] as String,
            explanation: item['explanation'] as String,
            difficulty: item['difficulty'] as int? ?? 3,
            frequencyWeight: (item['frequencyWeight'] as num?)?.toDouble() ?? 0.5,
          ));
        }
      } catch (e) {
        // 파일이 없거나 파싱 에러 시 건너뜀
      }
    }

    _cached = allQuestions;
    return allQuestions;
  }
}
