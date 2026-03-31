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
      // 전체/오늘 통계와 필드별 정확도 fetch
      final overall = await _db.getOverallStats();
      final subjectAcc = await _db.getAccuracyByField('subject');
      final typeAcc = await _db.getAccuracyByField('question_type');

      _stats = StudyStats(
        totalSolved: overall['total'] as int? ?? 0,
        totalCorrect: overall['correct'] as int? ?? 0,
        todaySolved: overall['todayTotal'] as int? ?? 0,
        todayCorrect: overall['todayCorrect'] as int? ?? 0,
        subjectAccuracy: subjectAcc,
        typeAccuracy: typeAcc,
        // streakDays: DB에 streak 추적 테이블 없으므로 0 유지
        streakDays: 0,
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
