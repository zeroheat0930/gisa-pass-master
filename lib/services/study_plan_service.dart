import 'package:flutter/foundation.dart';
import '../models/study_plan.dart';
import '../models/question.dart';
import 'database_service.dart';

class StudyPlanService extends ChangeNotifier {
  final DatabaseService _db;

  StudyPlan? _currentPlan;
  Map<int, DailyProgress> _progressMap = {};

  StudyPlan? get currentPlan => _currentPlan;
  Map<int, DailyProgress> get progressMap => _progressMap;

  /// 14일 미션 정의
  static const List<DailyMission> missions = [
    DailyMission(
      dayNumber: 1,
      title: '코드 분석 기초',
      description: 'C/Java/Python 코드 읽기의 기본기를 다집니다',
      icon: 'code',
      queryType: 'type',
      filterValue: 'code_reading',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 2,
      title: 'SQL 기초',
      description: 'SELECT, JOIN, 서브쿼리 핵심을 정복합니다',
      icon: 'storage',
      queryType: 'type',
      filterValue: 'sql',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 3,
      title: '단답형 핵심 개념',
      description: '자주 출제되는 핵심 용어를 암기합니다',
      icon: 'edit_note',
      queryType: 'type',
      filterValue: 'short_answer',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 4,
      title: '코드 분석 심화',
      description: '난이도 높은 코드 분석에 도전합니다',
      icon: 'code',
      queryType: 'type_difficulty',
      filterValue: 'code_reading',
      minDifficulty: 3,
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 5,
      title: 'SQL 심화',
      description: '복잡한 쿼리와 DDL/DCL을 마스터합니다',
      icon: 'storage',
      queryType: 'type_difficulty',
      filterValue: 'sql',
      minDifficulty: 3,
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 6,
      title: '약점 집중 공략',
      description: '오답률이 높은 문제를 집중 공략합니다',
      icon: 'local_fire_department',
      queryType: 'weakness',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 7,
      title: '중간 모의고사',
      description: '1주차 학습 성과를 점검합니다',
      icon: 'psychology',
      queryType: 'prediction',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 8,
      title: '오답 총복습',
      description: '지금까지 틀린 문제를 전부 다시 풀어봅니다',
      icon: 'replay',
      queryType: 'wrong',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 9,
      title: '빈출 유형 집중',
      description: '시험에 자주 나오는 문제만 골라 풀어봅니다',
      icon: 'trending_up',
      queryType: 'frequent',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 10,
      title: '혼합 실전 연습',
      description: '모든 유형을 섞어서 실전처럼 풀어봅니다',
      icon: 'shuffle',
      queryType: 'random',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 11,
      title: '고난이도 도전',
      description: '난이도 4~5 문제로 실력을 극한까지 끌어올립니다',
      icon: 'whatshot',
      queryType: 'hard',
      minDifficulty: 4,
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 12,
      title: '실전 모의고사',
      description: 'D-2! 실전과 동일한 환경으로 모의시험을 봅니다',
      icon: 'psychology',
      queryType: 'prediction',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 13,
      title: '최종 오답 정리',
      description: '마지막으로 틀린 문제를 완벽히 정리합니다',
      icon: 'checklist',
      queryType: 'all_wrong',
      questionCount: 50,
    ),
    DailyMission(
      dayNumber: 14,
      title: '시험 당일! 가볍게 복습',
      description: '족보 훑어보고 가벼운 문제로 컨디션 점검!',
      icon: 'emoji_events',
      queryType: 'review',
      questionCount: 10,
    ),
  ];

  /// 7일 미션 정의
  static const List<DailyMission> _7dayMissions = [
    DailyMission(
      dayNumber: 1,
      title: 'C/Java/Python 코드 분석 기초',
      description: '코드 읽기 기본기를 빠르게 다집니다',
      icon: 'code',
      queryType: 'type',
      filterValue: 'code_reading',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 2,
      title: 'SQL 기초+심화',
      description: 'SQL 전 범위를 한번에 정복합니다',
      icon: 'storage',
      queryType: 'type',
      filterValue: 'sql',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 3,
      title: '단답형 핵심 개념',
      description: '자주 출제되는 핵심 용어를 집중 암기합니다',
      icon: 'edit_note',
      queryType: 'type',
      filterValue: 'short_answer',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 4,
      title: '약점 집중 공략 + 오답 복습',
      description: '오답률 높은 문제를 집중 공략합니다',
      icon: 'local_fire_department',
      queryType: 'weakness',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 5,
      title: '혼합 실전 연습',
      description: '모든 유형을 섞어서 실전처럼 풀어봅니다',
      icon: 'shuffle',
      queryType: 'random',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 6,
      title: '실전 모의고사',
      description: 'D-1! 실전 환경으로 모의시험을 봅니다',
      icon: 'psychology',
      queryType: 'prediction',
      questionCount: 20,
    ),
    DailyMission(
      dayNumber: 7,
      title: '최종 오답 정리 + 가벼운 복습',
      description: '마지막 오답 정리 후 가볍게 마무리합니다',
      icon: 'emoji_events',
      queryType: 'all_wrong',
      questionCount: 20,
    ),
  ];

  /// 5일 미션 정의
  static const List<DailyMission> _5dayMissions = [
    DailyMission(
      dayNumber: 1,
      title: '코드 분석(C/Java/Python) 총정리',
      description: '코드 읽기 전 범위를 압축 정리합니다',
      icon: 'code',
      queryType: 'type',
      filterValue: 'code_reading',
      questionCount: 40,
    ),
    DailyMission(
      dayNumber: 2,
      title: 'SQL 총정리',
      description: 'SQL 전 범위를 압축 정리합니다',
      icon: 'storage',
      queryType: 'type',
      filterValue: 'sql',
      questionCount: 40,
    ),
    DailyMission(
      dayNumber: 3,
      title: '단답형 + 약점 공략',
      description: '단답형 암기와 약점을 동시에 잡습니다',
      icon: 'edit_note',
      queryType: 'type',
      filterValue: 'short_answer',
      questionCount: 40,
    ),
    DailyMission(
      dayNumber: 4,
      title: '실전 모의고사 + 오답 정리',
      description: '실전 모의고사 후 오답을 바로 정리합니다',
      icon: 'psychology',
      queryType: 'prediction',
      questionCount: 30,
    ),
    DailyMission(
      dayNumber: 5,
      title: '최종 복습 + 가벼운 워밍업',
      description: '마지막 복습으로 가볍게 마무리합니다',
      icon: 'emoji_events',
      queryType: 'review',
      questionCount: 20,
    ),
  ];

  /// 3일 미션 정의 (48시간 전사 모드)
  static const List<DailyMission> _3dayMissions = [
    DailyMission(
      dayNumber: 1,
      title: '코드+SQL 핵심만 압축',
      description: '코드와 SQL 핵심만 빠르게 훑습니다',
      icon: 'code',
      queryType: 'random',
      questionCount: 50,
    ),
    DailyMission(
      dayNumber: 2,
      title: '단답형 암기 + 실전 모의고사',
      description: '단답형 암기와 실전 감각을 동시에 잡습니다',
      icon: 'psychology',
      queryType: 'prediction',
      questionCount: 50,
    ),
    DailyMission(
      dayNumber: 3,
      title: '오답 총복습 + 최종 정리',
      description: '마지막 오답 정리로 완벽 마무리합니다',
      icon: 'emoji_events',
      queryType: 'all_wrong',
      questionCount: 30,
    ),
  ];

  /// 1일 미션 정의 (당일치기 전사 모드)
  static const List<DailyMission> _1dayMissions = [
    DailyMission(
      dayNumber: 1,
      title: '빈출 유형 총집합 + 족보 핵심',
      description: '빈출 문제와 족보 핵심만 총정리합니다',
      icon: 'whatshot',
      queryType: 'frequent',
      questionCount: 60,
    ),
  ];

  /// planType에 맞는 미션 목록 반환
  static List<DailyMission> getMissionsForPlanType(String planType) {
    switch (planType) {
      case '1day':
        return _1dayMissions;
      case '3day':
        return _3dayMissions;
      case '5day':
        return _5dayMissions;
      case '7day':
        return _7dayMissions;
      case '14day':
      default:
        return missions;
    }
  }

  StudyPlanService(this._db);

  /// 현재 진행 중인 플랜 로드
  Future<void> loadCurrentPlan() async {
    if (kIsWeb) return;
    final db = await _db.database;

    // study_plan 테이블 존재 확인
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='study_plan'",
    );
    if (tables.isEmpty) return;

    final plans = await db.query('study_plan', orderBy: 'id DESC', limit: 1);
    if (plans.isEmpty) {
      _currentPlan = null;
      _progressMap = {};
      notifyListeners();
      return;
    }

    _currentPlan = StudyPlan.fromMap(plans.first);
    await _loadProgress();
    notifyListeners();
  }

  Future<void> _loadProgress() async {
    if (_currentPlan == null) return;
    final db = await _db.database;
    final results = await db.query(
      'daily_progress',
      where: 'plan_id = ?',
      whereArgs: [_currentPlan!.id],
    );
    _progressMap = {
      for (final r in results)
        (r['day_number'] as int): DailyProgress.fromMap(r),
    };
  }

  /// 새 플랜 시작
  Future<void> startNewPlan({String planType = '14day'}) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final id = await db.insert('study_plan', {
      'started_at': DateTime.now().toIso8601String(),
      'current_day': 1,
      'plan_type': planType,
    });
    _currentPlan = StudyPlan(
      id: id,
      startedAt: DateTime.now(),
      currentDay: 1,
      planType: planType,
    );
    _progressMap = {};
    notifyListeners();
  }

  /// Day 완료 기록
  Future<void> completeDay(int dayNumber, int solved, int correct) async {
    if (kIsWeb || _currentPlan == null) return;
    final db = await _db.database;

    // 이미 완료된 Day는 업데이트
    final existing = await db.query(
      'daily_progress',
      where: 'plan_id = ? AND day_number = ?',
      whereArgs: [_currentPlan!.id, dayNumber],
    );

    if (existing.isEmpty) {
      final id = await db.insert('daily_progress', {
        'plan_id': _currentPlan!.id,
        'day_number': dayNumber,
        'completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
        'questions_solved': solved,
        'questions_correct': correct,
      });
      _progressMap[dayNumber] = DailyProgress(
        id: id,
        planId: _currentPlan!.id,
        dayNumber: dayNumber,
        completed: true,
        completedAt: DateTime.now(),
        questionsSolved: solved,
        questionsCorrect: correct,
      );
    } else {
      await db.update(
        'daily_progress',
        {
          'completed': 1,
          'completed_at': DateTime.now().toIso8601String(),
          'questions_solved': solved,
          'questions_correct': correct,
        },
        where: 'plan_id = ? AND day_number = ?',
        whereArgs: [_currentPlan!.id, dayNumber],
      );
      _progressMap[dayNumber] = DailyProgress.fromMap({
        ...existing.first,
        'completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
        'questions_solved': solved,
        'questions_correct': correct,
      });
    }
    notifyListeners();
  }

  /// Day별 문제 로드
  Future<List<Question>> getQuestionsForDay(int dayNumber) async {
    final planType = _currentPlan?.planType ?? '14day';
    final missionList = getMissionsForPlanType(planType);
    final mission = missionList.firstWhere((m) => m.dayNumber == dayNumber);
    final db = await _db.database;

    switch (mission.queryType) {
      case 'type':
        final maps = await db.query(
          'questions',
          where: 'question_type = ?',
          whereArgs: [mission.filterValue],
          orderBy: 'RANDOM()',
          limit: mission.questionCount,
        );
        return maps.map((m) => Question.fromMap(m)).toList();

      case 'type_difficulty':
        final maps = await db.query(
          'questions',
          where: 'question_type = ? AND difficulty >= ?',
          whereArgs: [mission.filterValue, mission.minDifficulty],
          orderBy: 'RANDOM()',
          limit: mission.questionCount,
        );
        return maps.map((m) => Question.fromMap(m)).toList();

      case 'weakness':
        final errorRates = await _db.getAllErrorRates();
        if (errorRates.isEmpty) {
          // 아직 풀어본 문제가 없으면 랜덤
          return await _db.getRandomQuestions(mission.questionCount);
        }
        final sorted = errorRates.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final weakIds = sorted.take(mission.questionCount).map((e) => e.key).toList();
        final questions = <Question>[];
        for (final id in weakIds) {
          final q = await _db.getQuestionById(id);
          if (q != null) questions.add(q);
        }
        if (questions.length < mission.questionCount) {
          final more = await _db.getRandomQuestions(mission.questionCount - questions.length);
          questions.addAll(more);
        }
        return questions;

      case 'prediction':
        final all = await _db.getAllQuestions();
        all.shuffle();
        return all.take(mission.questionCount).toList();

      case 'wrong':
      case 'all_wrong':
        final dueReviews = await _db.getDueReviews();
        final questions = dueReviews.map((m) => Question.fromMap(m)).toList();
        if (questions.isEmpty) {
          return await _db.getRandomQuestions(mission.questionCount);
        }
        if (mission.queryType == 'all_wrong') return questions;
        return questions.take(mission.questionCount).toList();

      case 'frequent':
        final maps = await db.query(
          'questions',
          orderBy: 'frequency_weight DESC',
          limit: mission.questionCount,
        );
        return maps.map((m) => Question.fromMap(m)).toList();

      case 'hard':
        final maps = await db.query(
          'questions',
          where: 'difficulty >= ?',
          whereArgs: [mission.minDifficulty],
          orderBy: 'RANDOM()',
          limit: mission.questionCount,
        );
        return maps.map((m) => Question.fromMap(m)).toList();

      case 'random':
        return await _db.getRandomQuestions(mission.questionCount);

      case 'review':
        return await _db.getRandomQuestions(mission.questionCount);

      default:
        return await _db.getRandomQuestions(mission.questionCount);
    }
  }

  /// 전체 완료율
  int get completedDays =>
      _progressMap.values.where((p) => p.completed).length;

  double get overallProgress {
    final total = _currentPlan?.totalDays ?? 14;
    return completedDays / total * 100;
  }

  /// 플랜 리셋
  Future<void> resetPlan() async {
    if (kIsWeb || _currentPlan == null) return;
    final db = await _db.database;
    await db.delete('daily_progress',
        where: 'plan_id = ?', whereArgs: [_currentPlan!.id]);
    await db.delete('study_plan',
        where: 'id = ?', whereArgs: [_currentPlan!.id]);
    _currentPlan = null;
    _progressMap = {};
    notifyListeners();
  }
}
