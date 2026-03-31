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
      final questions = await _db.getAllQuestions();
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
    if (question == null || _isAnswered) return;

    // 대소문자 무시, 앞뒤 공백 제거 후 비교
    final trimmedAnswer = answer.trim();
    final correct = question.answer.trim().toLowerCase() ==
        trimmedAnswer.toLowerCase();

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

    // 스파르타 복습 인터벌 갱신
    await _spacedRepetitionService.processAnswer(question.id!, correct);

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
    if (_questionIndex < _questionList.length - 1) {
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

  /// 모든 문제의 오답률 계산 (PredictionEngine 입력용)
  Future<Map<int, double>> _buildErrorRates(List<Question> questions) async {
    final errorRates = <int, double>{};
    for (final q in questions) {
      if (q.id == null) continue;
      final records = await _db.getRecordsByQuestion(q.id!);
      if (records.isEmpty) {
        errorRates[q.id!] = 0.0;
      } else {
        final wrongCount = records.where((r) => !r.isCorrect).length;
        errorRates[q.id!] = wrongCount / records.length;
      }
    }
    return errorRates;
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
