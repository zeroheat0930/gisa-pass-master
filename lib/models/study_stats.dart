class StudyStats {
  final int totalSolved;
  final int totalCorrect;
  final int todaySolved;
  final int todayCorrect;
  final Map<String, double> subjectAccuracy; // subject -> accuracy %
  final Map<String, double> typeAccuracy; // question_type -> accuracy %
  final int streakDays;

  StudyStats({
    this.totalSolved = 0,
    this.totalCorrect = 0,
    this.todaySolved = 0,
    this.todayCorrect = 0,
    this.subjectAccuracy = const {},
    this.typeAccuracy = const {},
    this.streakDays = 0,
  });

  double get totalAccuracy =>
      totalSolved > 0 ? (totalCorrect / totalSolved) * 100 : 0;

  double get todayAccuracy =>
      todaySolved > 0 ? (todayCorrect / todaySolved) * 100 : 0;
}
