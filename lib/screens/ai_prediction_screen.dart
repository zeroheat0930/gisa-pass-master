import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';

class AiPredictionScreen extends StatefulWidget {
  final List<Question> questions;

  const AiPredictionScreen({super.key, required this.questions});

  @override
  State<AiPredictionScreen> createState() => _AiPredictionScreenState();
}

class _AiPredictionScreenState extends State<AiPredictionScreen> {
  // Phase control
  bool _isLoading = true;
  bool _isFinished = false;

  // Quiz state
  int _currentIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _showExplanation = false;

  // Per-question results
  final List<String> _userAnswers = [];
  final List<bool> _isCorrectList = [];

  // Timer
  late final Stopwatch _stopwatch;
  Timer? _timerTick;
  String _elapsedDisplay = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _startLoadingPhase();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timerTick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ── Loading phase ─────────────────────────────────────────────────────────

  void _startLoadingPhase() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _startTimer();
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _stopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _stopwatch.elapsed;
      final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
  }

  void _stopTimer() {
    _timerTick?.cancel();
    _stopwatch.stop();
  }

  // ── Quiz actions ──────────────────────────────────────────────────────────

  static bool _isCorrectAnswer(String userAnswer, String correctAnswer) {
    String normalize(String s) => s
        .trim()
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final normUser = normalize(userAnswer);
    final normCorrect = normalize(correctAnswer);
    if (normUser == normCorrect) return true;
    if (normUser.replaceAll(' ', '') == normCorrect.replaceAll(' ', '')) return true;
    Set<String> tokens(String s) =>
        s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    if (tokens(normUser) == tokens(normCorrect)) return true;
    return false;
  }

  void _submit() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    final question = widget.questions[_currentIndex];
    final correct = _isCorrectAnswer(answer, question.answer);

    setState(() {
      _userAnswers.add(answer);
      _isCorrectList.add(correct);
      _showExplanation = true;
    });
  }

  void _next() {
    _answerController.clear();
    setState(() => _showExplanation = false);

    if (_currentIndex + 1 >= widget.questions.length) {
      _stopTimer();
      setState(() => _isFinished = true);
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _retry() {
    _timerTick?.cancel();
    _timerTick = null;
    _answerController.clear();
    _userAnswers.clear();
    _isCorrectList.clear();
    _stopwatch.reset();
    setState(() {
      _currentIndex = 0;
      _showExplanation = false;
      _isFinished = false;
      _isLoading = true;
    });
    _startLoadingPhase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_isFinished) return _buildResultsScreen();
    return _buildQuizScreen();
  }

  // ── Loading screen ────────────────────────────────────────────────────────

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                color: AppConfig.primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AI 예측 모의고사',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'AI가 출제 경향을 분석중...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quiz screen ───────────────────────────────────────────────────────────

  Widget _buildQuizScreen() {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: AppBar(title: const Text('AI 실전 모의고사')),
        body: const Center(
          child: Text('문제가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ),
      );
    }
    final question = widget.questions[_currentIndex];
    final total = widget.questions.length;
    final current = _currentIndex + 1;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          'AI 예측 모의고사',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _elapsedDisplay,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '$current / $total',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: current / total,
                        backgroundColor: AppConfig.borderColor,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppConfig.primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuestionCard(question: question),
                    const SizedBox(height: 20),

                    // Answer input
                    if (!_showExplanation) ...[
                      TextField(
                        controller: _answerController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '정답을 입력하세요',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: AppConfig.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppConfig.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppConfig.primaryColor, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppConfig.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('제출'),
                      ),
                    ],

                    // Explanation after answering
                    if (_showExplanation) ...[
                      const SizedBox(height: 16),
                      _ExplanationCard(
                        isCorrect: _isCorrectList.last,
                        correctAnswer: question.answer,
                        userAnswer: _userAnswers.last,
                        explanation: question.explanation,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _next,
                        icon: Icon(
                          _currentIndex + 1 >= widget.questions.length
                              ? Icons.bar_chart
                              : Icons.arrow_forward,
                        ),
                        label: Text(
                          _currentIndex + 1 >= widget.questions.length
                              ? '결과 보기'
                              : '다음 문제',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.cardColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side:
                              const BorderSide(color: AppConfig.borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Results screen ────────────────────────────────────────────────────────

  Widget _buildResultsScreen() {
    final total = widget.questions.length;
    final correct = _isCorrectList.where((v) => v).length;
    final passed = correct >= (total * 0.6).ceil();

    // Breakdown by question type
    final Map<String, int> typeTotal = {};
    final Map<String, int> typeCorrect = {};
    for (int i = 0; i < widget.questions.length; i++) {
      final type = widget.questions[i].questionType;
      typeTotal[type] = (typeTotal[type] ?? 0) + 1;
      if (i < _isCorrectList.length && _isCorrectList[i]) {
        typeCorrect[type] = (typeCorrect[type] ?? 0) + 1;
      }
    }

    final elapsed = _stopwatch.elapsed;
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeTaken = '$mm:$ss';

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          '결과',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pass/fail badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: (passed ? AppConfig.correctColor : AppConfig.wrongColor)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: passed
                          ? AppConfig.correctColor
                          : AppConfig.wrongColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    passed ? '합격' : '불합격',
                    style: TextStyle(
                      color: passed
                          ? AppConfig.correctColor
                          : AppConfig.wrongColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppConfig.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConfig.borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      '$correct / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(correct / total * 100).toStringAsFixed(0)}점',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '소요 시간: $timeTaken',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      passed
                          ? '합격 기준(60%)을 통과했습니다!'
                          : '합격 기준(60% = ${(total * 0.6).ceil()}문제)에 미달했습니다.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Breakdown by type
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConfig.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '유형별 결과',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...typeTotal.entries.map((entry) {
                      final type = entry.key;
                      final tTotal = entry.value;
                      final tCorrect = typeCorrect[type] ?? 0;
                      final label =
                          AppConfig.questionTypeLabels[type] ?? type;
                      final icon =
                          AppConfig.questionTypeIcons[type] ?? Icons.help_outline;
                      final ratio = tTotal > 0 ? tCorrect / tTotal : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon,
                                    size: 16, color: Colors.grey[400]),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                Text(
                                  '$tCorrect / $tTotal',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: AppConfig.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ratio >= 0.6
                                      ? AppConfig.correctColor
                                      : AppConfig.wrongColor,
                                ),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 풀기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text('홈으로'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.cardColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppConfig.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ExplanationCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String userAnswer;
  final String explanation;

  const _ExplanationCard({
    required this.isCorrect,
    required this.correctAnswer,
    required this.userAnswer,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isCorrect ? AppConfig.correctColor : AppConfig.wrongColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '정답!' : '오답',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isCorrect) ...[
            _InfoRow(label: '내 답', value: userAnswer, color: Colors.grey),
            const SizedBox(height: 6),
            _InfoRow(
                label: '정답',
                value: correctAnswer,
                color: AppConfig.correctColor),
            const SizedBox(height: 12),
          ],
          Text(
            '해설',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: const TextStyle(
              color: Color(0xFFD4D4D4),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            '$label:',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

