class AnswerRecord {
  final int? id;
  final int questionId;
  final bool isCorrect;
  final String userAnswer;
  final DateTime answeredAt;
  final int timeSpentSeconds;

  AnswerRecord({
    this.id,
    required this.questionId,
    required this.isCorrect,
    required this.userAnswer,
    required this.answeredAt,
    this.timeSpentSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'is_correct': isCorrect ? 1 : 0,
      'user_answer': userAnswer,
      'answered_at': answeredAt.toIso8601String(),
      'time_spent_seconds': timeSpentSeconds,
    };
  }

  factory AnswerRecord.fromMap(Map<String, dynamic> map) {
    return AnswerRecord(
      id: map['id'] as int?,
      questionId: map['question_id'] as int,
      isCorrect: (map['is_correct'] as int) == 1,
      userAnswer: map['user_answer'] as String,
      answeredAt: DateTime.parse(map['answered_at'] as String),
      timeSpentSeconds: map['time_spent_seconds'] as int? ?? 0,
    );
  }
}
