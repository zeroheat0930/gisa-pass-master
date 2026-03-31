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
    );
  }
}
