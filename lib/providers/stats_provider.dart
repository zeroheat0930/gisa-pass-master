import 'package:flutter/foundation.dart';
import '../models/study_stats.dart';
import '../services/database_service.dart';

/// 통계 상태 관리 Provider
class StatsProvider extends ChangeNotifier {
  final DatabaseService _db;

  StatsProvider({required DatabaseService db}) : _db = db;

  // === 상태 필드 ===
  StudyStats _stats = StudyStats();
  bool _isLoading = false;

  // === Getters ===
  StudyStats get stats => _stats;
  bool get isLoading => _isLoading;

  /// 전체 정답률 (%)
  double get totalAccuracy => _stats.totalAccuracy;

  /// 오늘 정답률 (%)
  double get todayAccuracy => _stats.todayAccuracy;

  /// 과목별 정답률 map
  Map<String, double> get subjectAccuracy => _stats.subjectAccuracy;

  /// 문제 유형별 정답률 map
  Map<String, double> get typeAccuracy => _stats.typeAccuracy;

  /// 연속 학습 일수
  int get streakDays => _stats.streakDays;

  // === 데이터 로딩 ===

  /// DB에서 전체 통계 및 세부 정확도 fetch 후 StudyStats 빌드
  Future<void> loadStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final overall = await _db.getOverallStats();
      final subjectAcc = await _db.getAccuracyByField('subject');
      final subjectSolved = await _db.getSolvedCountByField('subject');
      final typeAcc = await _db.getAccuracyByField('question_type');
      final typeSolved = await _db.getSolvedCountByField('question_type');
      final difficultyAcc = await _db.getAccuracyByDifficulty();
      final totalAvailable = await _db.getTotalQuestionCount();
      final streakDays = await _db.getStreakDays();
      final last7Raw = await _db.getLast7DaysStats();

      final last7Days = last7Raw.map((row) {
        final total = row['total'];
        final correct = row['correct'];
        return DailyStats(
          date: row['day'] as String,
          solved: total is int ? total : (total as num).toInt(),
          correct: correct is int ? correct : (correct as num).toInt(),
        );
      }).toList();

      _stats = StudyStats(
        totalSolved: overall['total'] as int? ?? 0,
        totalCorrect: overall['correct'] as int? ?? 0,
        todaySolved: overall['todayTotal'] as int? ?? 0,
        todayCorrect: overall['todayCorrect'] as int? ?? 0,
        totalAvailable: totalAvailable,
        subjectAccuracy: subjectAcc,
        subjectSolved: subjectSolved,
        typeAccuracy: typeAcc,
        typeSolved: typeSolved,
        difficultyAccuracy: difficultyAcc,
        streakDays: streakDays,
        last7Days: last7Days,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 통계 초기화 (테스트/디버그용)
  void reset() {
    _stats = StudyStats();
    notifyListeners();
  }
}
