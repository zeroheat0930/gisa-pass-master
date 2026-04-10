class StudyPlan {
  final int id;
  final DateTime startedAt;
  final int currentDay;

  StudyPlan({
    required this.id,
    required this.startedAt,
    required this.currentDay,
  });

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    return StudyPlan(
      id: map['id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      currentDay: (map['current_day'] as int?) ?? 1,
    );
  }

  /// 오늘이 플랜 시작일 기준 며칠째인지 계산
  int get todayDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
    return today.difference(start).inDays + 1;
  }
}

class DailyMission {
  final int dayNumber;
  final String title;
  final String description;
  final String icon;
  final String queryType; // 'type', 'difficulty', 'weakness', 'prediction', 'wrong', 'random', 'all_wrong', 'review'
  final String? filterValue;
  final int? minDifficulty;
  final int questionCount;

  const DailyMission({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.queryType,
    this.filterValue,
    this.minDifficulty,
    required this.questionCount,
  });
}

class DailyProgress {
  final int id;
  final int planId;
  final int dayNumber;
  final bool completed;
  final DateTime? completedAt;
  final int questionsSolved;
  final int questionsCorrect;

  DailyProgress({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.completed,
    this.completedAt,
    required this.questionsSolved,
    required this.questionsCorrect,
  });

  factory DailyProgress.fromMap(Map<String, dynamic> map) {
    return DailyProgress(
      id: map['id'] as int,
      planId: map['plan_id'] as int,
      dayNumber: map['day_number'] as int,
      completed: (map['completed'] as int) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      questionsSolved: (map['questions_solved'] as int?) ?? 0,
      questionsCorrect: (map['questions_correct'] as int?) ?? 0,
    );
  }

  double get accuracy =>
      questionsSolved > 0 ? (questionsCorrect / questionsSolved) * 100 : 0;
}
