class Question {
  final int? id;
  final int year;
  final int round;
  final String subject;
  final String questionType; // code_reading, sql, short_answer
  final String questionText;
  final String? codeSnippet;
  final String? codeLanguage; // c, java, sql
  final String answer;
  final String explanation;
  final int difficulty;
  final double frequencyWeight;

  /// 이 문항의 출처. `Question.sourceAi` 또는 `Question.sourceRestored`.
  ///
  /// **표기를 정직하게 유지하는 근거가 되는 필드다.** 이 앱 문항의 대부분은
  /// AI 가 만든 예상문제이고, 일부만 실제 시험을 응시자들이 복원한 기출이다.
  /// 화면에서 둘을 섞어 보여주거나 AI 문항을 기출로 표시하면 유저를 속이는 것이다.
  final String source;

  static const String sourceAi = 'ai';
  static const String sourceRestored = 'restored';

  bool get isRestored => source == sourceRestored;

  Question({
    this.id,
    required this.year,
    required this.round,
    required this.subject,
    required this.questionType,
    required this.questionText,
    this.codeSnippet,
    this.codeLanguage,
    required this.answer,
    required this.explanation,
    this.difficulty = 3,
    this.frequencyWeight = 0.5,
    this.source = sourceAi,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'round': round,
      'subject': subject,
      'question_type': questionType,
      'question_text': questionText,
      'code_snippet': codeSnippet,
      'code_language': codeLanguage,
      'answer': answer,
      'explanation': explanation,
      'difficulty': difficulty,
      'frequency_weight': frequencyWeight,
      'source': source,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int?,
      year: map['year'] as int,
      round: map['round'] as int,
      subject: map['subject'] as String,
      questionType: map['question_type'] as String,
      questionText: map['question_text'] as String,
      codeSnippet: map['code_snippet'] as String?,
      codeLanguage: map['code_language'] as String?,
      answer: map['answer'] as String,
      explanation: map['explanation'] as String,
      difficulty: map['difficulty'] as int? ?? 3,
      frequencyWeight: (map['frequency_weight'] as num?)?.toDouble() ?? 0.5,
      // 구버전 DB(v7 이하)에는 컬럼이 없다. 그때는 전부 AI 문항이었다.
      source: map['source'] as String? ?? sourceAi,
    );
  }
}
