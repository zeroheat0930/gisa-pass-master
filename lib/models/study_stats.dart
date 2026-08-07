class StudyStats {
  final int totalSolved;
  final int totalCorrect;
  final int todaySolved;
  final int todayCorrect;
  final int totalAvailable;

  /// 서로 다른 문제를 몇 개 풀어봤는지 (중복 제거).
  /// '완료율'은 반드시 이 값을 써야 한다. 총 풀이 수(totalSolved)를 쓰면 같은 문제를
  /// 여러 번 풀 때마다 진도가 오르고 "1500 / 1000" 같은 값이 표시된다.
  final int uniqueSolved;
  final Map<String, double> subjectAccuracy; // subject -> accuracy %
  final Map<String, int> subjectSolved; // subject -> solved count
  final Map<String, double> typeAccuracy; // question_type -> accuracy %
  final Map<String, int> typeSolved; // question_type -> solved count
  final Map<int, double> difficultyAccuracy; // difficulty (1-5) -> accuracy %
  final int streakDays;
  final List<DailyStats> last7Days;

  StudyStats({
    this.totalSolved = 0,
    this.totalCorrect = 0,
    this.todaySolved = 0,
    this.todayCorrect = 0,
    this.totalAvailable = 0,
    this.uniqueSolved = 0,
    this.subjectAccuracy = const {},
    this.subjectSolved = const {},
    this.typeAccuracy = const {},
    this.typeSolved = const {},
    this.difficultyAccuracy = const {},
    this.streakDays = 0,
    this.last7Days = const [],
  });

  double get totalAccuracy =>
      totalSolved > 0 ? (totalCorrect / totalSolved) * 100 : 0;

  double get todayAccuracy =>
      todaySolved > 0 ? (todayCorrect / todaySolved) * 100 : 0;

  double get completionRate =>
      totalAvailable > 0 ? (uniqueSolved / totalAvailable).clamp(0.0, 1.0) : 0;

  /// 완료율 표시용 문구. 총 문항 수를 넘길 수 없다.
  String get completionLabel {
    final done = uniqueSolved > totalAvailable ? totalAvailable : uniqueSolved;
    return '$done / $totalAvailable';
  }
}

class DailyStats {
  final String date; // yyyy-MM-dd
  final int solved;
  final int correct;

  DailyStats({
    required this.date,
    required this.solved,
    required this.correct,
  });

  double get accuracy => solved > 0 ? (correct / solved) * 100 : 0;

  String get displayDate {
    // Convert yyyy-MM-dd to MM/dd
    final parts = date.split('-');
    if (parts.length == 3) return '${parts[1]}/${parts[2]}';
    return date;
  }
}
