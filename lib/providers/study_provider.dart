import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/question.dart';
import '../models/answer_record.dart';
import '../services/database_service.dart';
import '../services/prediction_engine.dart';
import '../services/spaced_repetition_service.dart';
import '../services/ad_service.dart';

/// 학습 모드 열거형
enum StudyMode {
  prediction,   // 출제 예측 모드 (PredictionEngine 기반)
  wrongAnswer,  // 오답노트 모드 (SpacedRepetitionService 기반)
  byType,       // 유형별 학습 모드
}

/// 중앙 학습 상태 관리 Provider
class StudyProvider extends ChangeNotifier {
  final DatabaseService _db;
  final PredictionEngine _predictionEngine;
  final SpacedRepetitionService _spacedRepetitionService;
  final AdService? _adService;

  StudyProvider({
    required DatabaseService db,
    required PredictionEngine predictionEngine,
    required SpacedRepetitionService spacedRepetitionService,
    AdService? adService,
  })  : _db = db,
        _predictionEngine = predictionEngine,
        _spacedRepetitionService = spacedRepetitionService,
        _adService = adService;

  // === 상태 필드 ===
  List<Question> _questionList = [];
  int _questionIndex = 0;
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _userAnswer = '';
  bool _isLoading = false;
  StudyMode _studyMode = StudyMode.prediction;
  int _consecutiveAnswers = 0;
  bool _shouldShowAd = false;

  // === Getters ===
  DatabaseService get db => _db;
  List<Question> get questionList => _questionList;
  int get questionIndex => _questionIndex;
  bool get isAnswered => _isAnswered;
  bool get isCorrect => _isCorrect;
  String get userAnswer => _userAnswer;
  bool get isLoading => _isLoading;
  StudyMode get studyMode => _studyMode;
  bool get shouldShowAd => _shouldShowAd;

  /// 광고 표시 플래그 리셋 (UI에서 광고 표시 후 호출)
  void clearAdFlag() {
    _shouldShowAd = false;
  }

  /// 현재 문제 (목록이 비어있으면 null)
  Question? get currentQuestion =>
      _questionList.isNotEmpty && _questionIndex < _questionList.length
          ? _questionList[_questionIndex]
          : null;

  /// 마지막 문제 여부
  bool get isLastQuestion =>
      _questionList.isNotEmpty && _questionIndex >= _questionList.length - 1;

  // === 문제 로딩 ===

  /// 출제 예측 모드: PredictionEngine으로 우선순위 정렬된 문제 로드
  Future<void> loadQuestions() async {
    _setLoading(true);
    _studyMode = StudyMode.prediction;

    try {
      final questions = await _db.getRandomQuestions(50);
      final errorRates = await _buildErrorRates(questions);
      _questionList = _predictionEngine.getPrioritizedQuestions(questions, errorRates);
      _questionIndex = 0;
      _resetSession();
    } finally {
      _setLoading(false);
    }
  }

  /// 오답노트 모드: 스파르타 복습 기한이 된 문제 로드
  Future<void> loadWrongAnswerQuestions() async {
    _setLoading(true);
    _studyMode = StudyMode.wrongAnswer;

    try {
      _questionList = await _spacedRepetitionService.getDueQuestions();
      _questionIndex = 0;
      _resetSession();
    } finally {
      _setLoading(false);
    }
  }

  /// 유형별 학습 모드: 특정 문제 유형으로 필터링
  Future<void> loadQuestionsByType(String type) async {
    _setLoading(true);
    _studyMode = StudyMode.byType;

    try {
      final questions = await _db.getQuestionsByType(type);
      _questionList = questions;
      _questionIndex = 0;
      _resetSession();
    } finally {
      _setLoading(false);
    }
  }

  // === 답안 제출 ===

  /// 답안 제출: 정답 확인, DB 기록, 스파르타 복습 스케줄 갱신
  Future<void> submitAnswer(String answer) async {
    final question = currentQuestion;
    if (question == null || _isAnswered || question.id == null) return;

    final trimmedAnswer = answer.trim();
    final correct = _isCorrectAnswer(trimmedAnswer, question.answer);

    _userAnswer = trimmedAnswer;
    _isAnswered = true;
    _isCorrect = correct;
    notifyListeners();

    // 답안 기록 DB 저장
    final record = AnswerRecord(
      questionId: question.id!,
      isCorrect: correct,
      userAnswer: trimmedAnswer,
      answeredAt: DateTime.now(),
    );
    await _db.insertAnswerRecord(record);

    // 스파르타 오답노트: 틀린 문제만 복습 스케줄에 등록
    if (!correct) {
      await _spacedRepetitionService.processAnswer(question.id!, correct);
    }

    // 연속 풀이 카운트 → 전면광고 트리거
    _consecutiveAnswers++;
    if (_consecutiveAnswers >= AppConfig.adIntervalQuestions) {
      _consecutiveAnswers = 0;
      _shouldShowAd = true;
      _adService?.showInterstitialAd();
      notifyListeners();
    }
  }

  // === 문제 이동 ===

  /// 다음 문제로 이동
  void nextQuestion() {
    if (_questionIndex < _questionList.length) {
      _questionIndex++;
      _resetAnswerState();
      notifyListeners();
    }
  }

  /// 이전 문제로 이동
  void previousQuestion() {
    if (_questionIndex > 0) {
      _questionIndex--;
      _resetAnswerState();
      notifyListeners();
    }
  }

  // === 내부 헬퍼 ===

  /// 답안 비교 (줄바꿈, 쉼표 순서, 공백, 대소문자 무시)
  static bool _isCorrectAnswer(String userAnswer, String correctAnswer) {
    String normalize(String s) => s
        .trim()
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();

    final normUser = normalize(userAnswer);
    final normCorrect = normalize(correctAnswer);
    if (normUser == normCorrect) return true;

    // 공백 완전 제거 비교 (상호배제 vs 상호 배제)
    if (normUser.replaceAll(' ', '') == normCorrect.replaceAll(' ', '')) return true;

    // 쉼표 리스트 순서 무관 비교
    Set<String> tokens(String s) =>
        s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    if (tokens(normUser) == tokens(normCorrect)) return true;

    return false;
  }

  /// 모든 문제의 오답률 계산 (PredictionEngine 입력용) — 단일 쿼리
  Future<Map<int, double>> _buildErrorRates(List<Question> questions) async {
    return await _db.getAllErrorRates();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _resetAnswerState() {
    _isAnswered = false;
    _isCorrect = false;
    _userAnswer = '';
  }

  void _resetSession() {
    _resetAnswerState();
    _consecutiveAnswers = 0;
    _shouldShowAd = false;
  }
}
