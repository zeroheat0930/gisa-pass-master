import 'package:flutter/foundation.dart';
import '../config.dart';
import '../models/question.dart';
import '../models/answer_record.dart';
import '../services/database_service.dart';
import '../services/prediction_engine.dart';
import '../services/spaced_repetition_service.dart';
import '../services/ad_service.dart';
import '../services/answer_checker.dart';

/// 학습 모드 열거형
enum StudyMode {
  prediction,   // 출제 예측 모드 (PredictionEngine 기반)
  wrongAnswer,  // 오답노트 모드 (SpacedRepetitionService 기반)
  byType,       // 유형별 학습 모드
  bookmark,     // 즐겨찾기 모드
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
  int _comboCount = 0;
  int _maxCombo = 0;

  /// 이번 세션에서 푼 문제 수 / 맞힌 문제 수.
  /// 학습플랜 '미션 완료' 기록에 쓰인다. 예전에는 화면이 정답 수를 추측해서
  /// (문제 리스트 길이) 넘기는 바람에 일별 정답률이 **항상 100%** 로 기록됐다.
  int _sessionSolved = 0;
  int _sessionCorrect = 0;

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
  int get comboCount => _comboCount;
  int get maxCombo => _maxCombo;
  int get sessionSolved => _sessionSolved;
  int get sessionCorrect => _sessionCorrect;

  /// 콤보 카운트 리셋
  void resetCombo() {
    _comboCount = 0;
  }

  /// 현재 문제 (목록이 비어있으면 null)
  Question? get currentQuestion =>
      _questionList.isNotEmpty && _questionIndex < _questionList.length
          ? _questionList[_questionIndex]
          : null;

  /// 마지막 문제 여부
  bool get isLastQuestion =>
      _questionList.isNotEmpty && _questionIndex >= _questionList.length - 1;

  /// 한 세션에 내보내는 문항 수
  static const int sessionQuestionCount = 50;

  // === 문제 로딩 ===

  /// 출제 예측 모드: PredictionEngine으로 우선순위 정렬된 문제 로드
  Future<void> loadQuestions() async {
    _setLoading(true);
    _studyMode = StudyMode.prediction;

    try {
      final questions = await _db.getAllQuestions();
      final errorRates = await _buildErrorRates(questions);
      _questionList = _predictionEngine.selectForSession(
        questions,
        errorRates,
        sessionSize: sessionQuestionCount,
      );
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

  /// 즐겨찾기 모드: 북마크된 문제 로드
  Future<void> loadBookmarkedQuestions() async {
    _setLoading(true);
    _studyMode = StudyMode.bookmark;

    try {
      _questionList = await _db.getBookmarkedQuestions();
      _questionIndex = 0;
      _resetSession();
    } finally {
      _setLoading(false);
    }
  }

  /// 북마크 토글
  Future<void> toggleBookmark(int questionId) async {
    await _db.toggleBookmark(questionId);
    notifyListeners();
  }

  /// 북마크 여부 확인
  Future<bool> isBookmarked(int questionId) async {
    return await _db.isBookmarked(questionId);
  }

  /// 외부에서 문제 리스트 직접 세팅 (14일 플랜용)
  void setQuestions(List<Question> questions) {
    _studyMode = StudyMode.prediction;
    _questionList = questions;
    _questionIndex = 0;
    _resetSession();
    notifyListeners();
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
    final correct = AnswerChecker.isCorrectFor(question, trimmedAnswer);

    _userAnswer = trimmedAnswer;
    _isAnswered = true;
    _isCorrect = correct;
    notifyListeners();

    await _persistAnswer(question.id!, trimmedAnswer, correct);

    // 세션 집계 (학습플랜 미션 완료 기록용)
    _sessionSolved++;
    if (correct) _sessionCorrect++;

    // 콤보 카운트 갱신
    if (correct) {
      _comboCount++;
      if (_comboCount > _maxCombo) _maxCombo = _comboCount;
    } else {
      _comboCount = 0;
    }

    // 연속 풀이 카운트 → 전면광고 예약.
    // 여기서 바로 띄우면 정답/오답 이펙트와 해설 위로 광고가 덮인다.
    // 유저가 채점 결과를 못 보고 광고를 맞으니 이탈로 이어진다.
    // 실제 표시는 '다음 문제'로 넘어갈 때(nextQuestion) 한다.
    _consecutiveAnswers++;
    if (_consecutiveAnswers >= AppConfig.adIntervalQuestions) {
      _consecutiveAnswers = 0;
      _shouldShowAd = true;
    }
    notifyListeners();
  }

  // === 문제 이동 ===

  /// 다음 문제로 이동
  void nextQuestion() {
    // 예약된 전면광고를 여기서 띄운다. 해설을 다 본 뒤라 이펙트를 가리지 않는다.
    if (_shouldShowAd) {
      _shouldShowAd = false;
      _adService?.showInterstitialAd();
    }

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

  /// 문제은행·AI 모의고사처럼 StudyProvider 의 문제 흐름을 쓰지 않는 화면에서
  /// 풀이 결과를 기록한다.
  ///
  /// 이 경로가 없어서 해당 화면들의 풀이가 **DB에 전혀 기록되지 않았고**,
  /// 통계·오답노트·스트릭·AI 예측이 모두 0으로 남았다. 기록 로직을 화면마다
  /// 복붙하면 또 한쪽만 고쳐지므로, 반드시 이 진입점을 쓸 것.
  Future<void> recordAnswer({
    required Question question,
    required String userAnswer,
    required bool isCorrect,
  }) async {
    if (question.id == null) return;
    await _persistAnswer(question.id!, userAnswer.trim(), isCorrect);
  }

  /// 풀이 기록 + 복습 스케줄 갱신 (단일 정본)
  ///
  /// 기록 실패로 풀이 자체를 막지 않는다. 예전에는 DB 쓰기 예외가 그대로 튀어나가
  /// 호출부(화면)의 후속 코드가 실행되지 않았고, 입력창·제출·다음 버튼이 모두
  /// 사라진 채 그 문제에서 진행이 고착됐다. 채점은 이미 끝난 뒤이므로 기록만 포기한다.
  Future<void> _persistAnswer(
      int questionId, String userAnswer, bool isCorrect) async {
    try {
      await _db.insertAnswerRecord(AnswerRecord(
        questionId: questionId,
        isCorrect: isCorrect,
        userAnswer: userAnswer,
        answeredAt: DateTime.now(),
      ));

      // 스파르타 오답노트 스케줄 갱신 — 정답일 때도 반드시 호출한다.
      // 정답을 걸러내면 stage 승격이 일어나지 않아 오답노트가 영원히 비워지지 않고
      // 복습 간격도 1분에 고정된다. '오답만 큐에 진입' 규칙은 서비스 내부가 담당한다.
      await _spacedRepetitionService.processAnswer(questionId, isCorrect);
    } catch (e) {
      debugPrint('풀이 기록 실패 (진행은 계속): $e');
    }
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
    _comboCount = 0;
    _maxCombo = 0;
    _sessionSolved = 0;
    _sessionCorrect = 0;
  }
}
