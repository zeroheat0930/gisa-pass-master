import '../config.dart';

class StudyPlan {
  final int id;
  final DateTime startedAt;
  final int currentDay;
  final String planType; // '14day', '7day', '5day', '3day', '1day'

  StudyPlan({
    required this.id,
    required this.startedAt,
    required this.currentDay,
    this.planType = '14day',
  });

  /// planType에 따른 총 일수
  int get totalDays {
    switch (planType) {
      case '1day':
        return 1;
      case '3day':
        return 3;
      case '5day':
        return 5;
      case '7day':
        return 7;
      case '14day':
      default:
        return 14;
    }
  }

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    return StudyPlan(
      id: map['id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      currentDay: (map['current_day'] as int?) ?? 1,
      planType: (map['plan_type'] as String?) ?? '14day',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'current_day': currentDay,
      'plan_type': planType,
    };
  }

  /// 오늘이 플랜 시작일 기준 며칠째인지 계산
  /// (AppConfig.now — 테스트에서 고정한 '오늘' 을 따라가야 화면 판정과 맞는다)
  int get todayDay {
    final now = AppConfig.now;
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
    return (today.difference(start).inDays + 1).clamp(1, totalDays);
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

  /// 실제 날짜로 계산한 'D-N!' 을 설명 앞에 붙이는 미션(실전 모의고사 자리).
  /// 문구에 D-숫자를 박아두면 시작일에 따라 시험 뒤에도 'D-2!' 가 뜬다.
  final bool showsExamCountdown;

  const DailyMission({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.queryType,
    this.filterValue,
    this.minDifficulty,
    required this.questionCount,
    this.showsExamCountdown = false,
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
