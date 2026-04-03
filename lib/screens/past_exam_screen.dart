import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class PastExamScreen extends StatefulWidget {
  final Future<List<Question>> Function() loadQuestions;

  const PastExamScreen({super.key, required this.loadQuestions});

  @override
  State<PastExamScreen> createState() => _PastExamScreenState();
}

// ── Screen phase enum ─────────────────────────────────────────────────────────

enum _Phase { loading, error, category, practice, exam, examResult }

enum _Difficulty { beginner, intermediate, advanced }

extension _DifficultyExt on _Difficulty {
  String get label {
    switch (this) {
      case _Difficulty.beginner:
        return '초급';
      case _Difficulty.intermediate:
        return '중급';
      case _Difficulty.advanced:
        return '고급';
    }
  }

  String get rangeLabel {
    switch (this) {
      case _Difficulty.beginner:
        return '난이도 1-2';
      case _Difficulty.intermediate:
        return '난이도 3';
      case _Difficulty.advanced:
        return '난이도 4-5';
    }
  }

  int get minDiff {
    switch (this) {
      case _Difficulty.beginner:
        return 1;
      case _Difficulty.intermediate:
        return 3;
      case _Difficulty.advanced:
        return 4;
    }
  }

  int get maxDiff {
    switch (this) {
      case _Difficulty.beginner:
        return 2;
      case _Difficulty.intermediate:
        return 3;
      case _Difficulty.advanced:
        return 5;
    }
  }

  Color get accentColor {
    switch (this) {
      case _Difficulty.beginner:
        return const Color(0xFF4CAF50);
      case _Difficulty.intermediate:
        return const Color(0xFF2196F3);
      case _Difficulty.advanced:
        return const Color(0xFFE53935);
    }
  }

  IconData get icon {
    switch (this) {
      case _Difficulty.beginner:
        return Icons.school;
      case _Difficulty.intermediate:
        return Icons.trending_up;
      case _Difficulty.advanced:
        return Icons.local_fire_department;
    }
  }
}

// ── Root state ────────────────────────────────────────────────────────────────

class _PastExamScreenState extends State<PastExamScreen> {
  _Phase _phase = _Phase.loading;
  String? _errorMessage;
  List<Question> _allQuestions = [];

  // Sub-screen params
  List<Question> _activeQuestions = [];
  String _modeTitle = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final qs = await widget.loadQuestions();
      if (!mounted) return;
      setState(() {
        _allQuestions = qs;
        _phase = _Phase.category;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _phase = _Phase.error;
      });
    }
  }

  List<Question> _filterByDifficulty(int min, int max) {
    final filtered =
        _allQuestions.where((q) => q.difficulty >= min && q.difficulty <= max).toList();
    filtered.shuffle();
    return filtered;
  }

  void _startPractice(_Difficulty diff) {
    final qs = _filterByDifficulty(diff.minDiff, diff.maxDiff);
    if (qs.isEmpty) {
      _showEmpty();
      return;
    }
    setState(() {
      _activeQuestions = qs.take(50).toList();
      _modeTitle = '${diff.label} 연습 모드';
      _phase = _Phase.practice;
    });
  }

  void _startExam(_Difficulty diff) {
    final qs = _filterByDifficulty(diff.minDiff, diff.maxDiff);
    if (qs.isEmpty) {
      _showEmpty();
      return;
    }
    setState(() {
      _activeQuestions = qs.take(20).toList();
      _modeTitle = '${diff.label} 실전 모의고사';
      _phase = _Phase.exam;
    });
  }

  void _startFullExam() {
    final all = List<Question>.from(_allQuestions)..shuffle();
    if (all.isEmpty) {
      _showEmpty();
      return;
    }
    setState(() {
      _activeQuestions = all.take(20).toList();
      _modeTitle = '실전 모의고사 20문제';
      _phase = _Phase.exam;
    });
  }

  void _showEmpty() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('해당 난이도의 문제가 없습니다.')),
    );
  }

  void _backToCategory() {
    setState(() => _phase = _Phase.category);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return _LoadingScreen();
      case _Phase.error:
        return _ErrorScreen(message: _errorMessage ?? '오류가 발생했습니다.', onRetry: _load);
      case _Phase.category:
        return _CategoryScreen(
          allQuestions: _allQuestions,
          onPractice: _startPractice,
          onExam: _startExam,
          onFullExam: _startFullExam,
        );
      case _Phase.practice:
        return _PracticeScreen(
          questions: _activeQuestions,
          title: _modeTitle,
          onBack: _backToCategory,
        );
      case _Phase.exam:
        return _ExamScreen(
          questions: _activeQuestions,
          title: _modeTitle,
          onBack: _backToCategory,
        );
      case _Phase.examResult:
        // examResult is handled inside _ExamScreen
        return _LoadingScreen();
    }
  }
}

// ── Loading screen ────────────────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: AppConfig.primaryColor,
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'AI 문제은행',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '문제를 불러오는 중...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error screen ──────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('AI 문제은행'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppConfig.wrongColor, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category screen ───────────────────────────────────────────────────────────

class _CategoryScreen extends StatelessWidget {
  final List<Question> allQuestions;
  final void Function(_Difficulty) onPractice;
  final void Function(_Difficulty) onExam;
  final VoidCallback onFullExam;

  const _CategoryScreen({
    required this.allQuestions,
    required this.onPractice,
    required this.onExam,
    required this.onFullExam,
  });

  int _countForDifficulty(_Difficulty diff) {
    return allQuestions
        .where((q) => q.difficulty >= diff.minDiff && q.difficulty <= diff.maxDiff)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          'AI 문제은행',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AI description banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppConfig.primaryColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: AppConfig.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '최근 3개년 출제 트렌드를 AI가 분석하여 출제 확률이 높은 문제를 예측했습니다',
                        style: TextStyle(
                          color: Color(0xFFFFCDD2),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full exam button
              GestureDetector(
                onTap: onFullExam,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor.withValues(alpha: 0.9),
                        const Color(0xFFB71C1C),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '실전 모의고사 20문제',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '전체 난이도 · 무작위 20문제 · 시험 종료 후 채점',
                              style: TextStyle(
                                color: Color(0xFFFFCDD2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                '난이도별 학습',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Difficulty cards
              ..._Difficulty.values.map((diff) {
                final count = _countForDifficulty(diff);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DifficultyCard(
                    difficulty: diff,
                    questionCount: count,
                    onPractice: () => onPractice(diff),
                    onExam: () => onExam(diff),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Difficulty card ───────────────────────────────────────────────────────────

class _DifficultyCard extends StatelessWidget {
  final _Difficulty difficulty;
  final int questionCount;
  final VoidCallback onPractice;
  final VoidCallback onExam;

  const _DifficultyCard({
    required this.difficulty,
    required this.questionCount,
    required this.onPractice,
    required this.onExam,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(difficulty.icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      difficulty.rangeLabel,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$questionCount문제',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPractice,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('연습 모드'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: AppConfig.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onExam,
                    icon: const Icon(Icons.assignment_outlined, size: 16),
                    label: const Text('실전 모의고사'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Practice screen ───────────────────────────────────────────────────────────

class _PracticeScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;
  final VoidCallback onBack;

  const _PracticeScreen({
    required this.questions,
    required this.title,
    required this.onBack,
  });

  @override
  State<_PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<_PracticeScreen> {
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  bool _showExplanation = false;

  final List<String> _userAnswers = [];
  final List<bool> _isCorrectList = [];

  bool _isFinished = false;

  late final Stopwatch _stopwatch;
  Timer? _timerTick;
  String _elapsedDisplay = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final e = _stopwatch.elapsed;
      final mm = e.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = e.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timerTick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  static bool _isCorrectAnswer(String user, String correct) {
    String normalize(String s) => s
        .trim()
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final u = normalize(user);
    final c = normalize(correct);
    if (u == c) return true;
    if (u.replaceAll(' ', '') == c.replaceAll(' ', '')) return true;
    Set<String> tokens(String s) =>
        s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    return tokens(u) == tokens(c);
  }

  void _submit() {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;
    final q = widget.questions[_currentIndex];
    setState(() {
      _userAnswers.add(answer);
      _isCorrectList.add(_isCorrectAnswer(answer, q.answer));
      _showExplanation = true;
    });
  }

  void _next() {
    _controller.clear();
    setState(() => _showExplanation = false);
    if (_currentIndex + 1 >= widget.questions.length) {
      _timerTick?.cancel();
      _stopwatch.stop();
      setState(() => _isFinished = true);
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _retry() {
    _timerTick?.cancel();
    _controller.clear();
    _userAnswers.clear();
    _isCorrectList.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final e = _stopwatch.elapsed;
      final mm = e.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = e.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
    setState(() {
      _currentIndex = 0;
      _showExplanation = false;
      _isFinished = false;
      _elapsedDisplay = '00:00';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildResults();
    return _buildQuiz();
  }

  Widget _buildQuiz() {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _appBar(),
        body: const Center(
          child: Text('문제가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    final q = widget.questions[_currentIndex];
    final total = widget.questions.length;
    final current = _currentIndex + 1;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: _appBar(),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(current: current, total: total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuestionCard(question: q),
                    const SizedBox(height: 20),

                    if (!_showExplanation) ...[
                      _AnswerTextField(
                        controller: _controller,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 14),
                      _PrimaryButton(label: '제출', onPressed: _submit),
                    ],

                    if (_showExplanation) ...[
                      const SizedBox(height: 16),
                      _ExplanationCard(
                        isCorrect: _isCorrectList.last,
                        correctAnswer: q.answer,
                        userAnswer: _userAnswers.last,
                        explanation: q.explanation,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _next,
                        icon: Icon(current >= total
                            ? Icons.bar_chart
                            : Icons.arrow_forward),
                        label: Text(current >= total ? '결과 보기' : '다음 문제'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.cardColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppConfig.borderColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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

  Widget _buildResults() {
    final total = widget.questions.length;
    final correct = _isCorrectList.where((v) => v).length;
    final passed = correct >= (total * 0.6).ceil();
    final elapsed = _stopwatch.elapsed;
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeTaken = '$mm:$ss';

    final Map<String, int> typeTotal = {};
    final Map<String, int> typeCorrect = {};
    for (int i = 0; i < widget.questions.length; i++) {
      final type = widget.questions[i].questionType;
      typeTotal[type] = (typeTotal[type] ?? 0) + 1;
      if (i < _isCorrectList.length && _isCorrectList[i]) {
        typeCorrect[type] = (typeCorrect[type] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('연습 결과', style: TextStyle(fontWeight: FontWeight.w700)),
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
              _PassFailBadge(passed: passed),
              const SizedBox(height: 24),
              _ScoreCard(
                  correct: correct,
                  total: total,
                  timeTaken: timeTaken,
                  passed: passed),
              const SizedBox(height: 24),
              _TypeBreakdown(
                  typeTotal: typeTotal, typeCorrect: typeCorrect),
              const SizedBox(height: 32),
              _PrimaryButton(label: '다시 풀기', onPressed: _retry,
                  icon: Icons.refresh),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: '홈으로',
                icon: Icons.home_outlined,
                onPressed: widget.onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: AppConfig.backgroundColor,
      foregroundColor: Colors.white,
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _elapsedDisplay,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Exam screen ───────────────────────────────────────────────────────────────

class _ExamScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;
  final VoidCallback onBack;

  const _ExamScreen({
    required this.questions,
    required this.title,
    required this.onBack,
  });

  @override
  State<_ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<_ExamScreen> {
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  final List<String> _userAnswers = [];

  bool _isFinished = false;

  late final Stopwatch _stopwatch;
  Timer? _timerTick;
  String _elapsedDisplay = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final e = _stopwatch.elapsed;
      final mm = e.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = e.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timerTick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  static bool _isCorrectAnswer(String user, String correct) {
    String normalize(String s) => s
        .trim()
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final u = normalize(user);
    final c = normalize(correct);
    if (u == c) return true;
    if (u.replaceAll(' ', '') == c.replaceAll(' ', '')) return true;
    Set<String> tokens(String s) =>
        s.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();
    return tokens(u) == tokens(c);
  }

  void _next() {
    final answer = _controller.text.trim();
    // Record answer (empty string if skipped)
    setState(() {
      _userAnswers.add(answer);
    });
    _controller.clear();

    if (_currentIndex + 1 >= widget.questions.length) {
      _timerTick?.cancel();
      _stopwatch.stop();
      setState(() => _isFinished = true);
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _retry() {
    _timerTick?.cancel();
    _controller.clear();
    _userAnswers.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final e = _stopwatch.elapsed;
      final mm = e.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = e.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
    setState(() {
      _currentIndex = 0;
      _isFinished = false;
      _elapsedDisplay = '00:00';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildResults();
    return _buildExam();
  }

  Widget _buildExam() {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _appBar(),
        body: const Center(
          child: Text('문제가 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    final q = widget.questions[_currentIndex];
    final total = widget.questions.length;
    final current = _currentIndex + 1;
    final isLast = current >= total;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: _appBar(),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(current: current, total: total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Exam mode notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppConfig.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppConfig.warningColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: AppConfig.warningColor, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '실전 모드 — 모든 문제 완료 후 채점됩니다',
                            style: TextStyle(
                              color: Colors.orange[200],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    QuestionCard(question: q),
                    const SizedBox(height: 20),

                    _AnswerTextField(
                      controller: _controller,
                      onSubmitted: (_) => _next(),
                    ),
                    const SizedBox(height: 14),

                    ElevatedButton.icon(
                      onPressed: _next,
                      icon: Icon(isLast ? Icons.bar_chart : Icons.arrow_forward),
                      label: Text(isLast ? '제출 및 채점' : '다음'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final total = widget.questions.length;
    final List<bool> isCorrectList = List.generate(
      total,
      (i) => i < _userAnswers.length
          ? _isCorrectAnswer(_userAnswers[i], widget.questions[i].answer)
          : false,
    );
    final correct = isCorrectList.where((v) => v).length;
    final passed = correct >= (total * 0.6).ceil();
    final elapsed = _stopwatch.elapsed;
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeTaken = '$mm:$ss';

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text('모의고사 결과',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
              _PassFailBadge(passed: passed),
              const SizedBox(height: 24),
              _ScoreCard(
                  correct: correct,
                  total: total,
                  timeTaken: timeTaken,
                  passed: passed),
              const SizedBox(height: 24),

              // Question review list
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
                      '문제별 결과',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(total, (i) {
                      final q = widget.questions[i];
                      final userAns = i < _userAnswers.length
                          ? _userAnswers[i]
                          : '';
                      final ok = isCorrectList[i];
                      return _ExamResultItem(
                        index: i + 1,
                        question: q,
                        userAnswer: userAns,
                        isCorrect: ok,
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Share button
              ElevatedButton.icon(
                onPressed: () async {
                  final percent =
                      (correct / total * 100).toStringAsFixed(0);
                  final daysLeft =
                      AppConfig.examDate.difference(DateTime.now()).inDays;
                  final text = '📝 기사패스마스터 실전 모의고사\n'
                      '${widget.title}\n'
                      '${total}문제 중 ${correct}문제 정답!\n'
                      '정답률: $percent% ${passed ? '✅ 합격' : '❌ 불합격'}\n'
                      '소요 시간: $timeTaken\n'
                      '📅 시험까지 D-$daysLeft\n\n'
                      '#정보처리기사 #기사패스마스터';
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('결과가 복사되었습니다! 붙여넣기로 공유하세요')),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('결과 공유하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.cardColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppConfig.borderColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryButton(label: '다시 풀기', onPressed: _retry, icon: Icons.refresh),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: '홈으로',
                icon: Icons.home_outlined,
                onPressed: widget.onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: AppConfig.backgroundColor,
      foregroundColor: Colors.white,
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _elapsedDisplay,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Exam result item (expandable) ─────────────────────────────────────────────

class _ExamResultItem extends StatefulWidget {
  final int index;
  final Question question;
  final String userAnswer;
  final bool isCorrect;

  const _ExamResultItem({
    required this.index,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
  });

  @override
  State<_ExamResultItem> createState() => _ExamResultItemState();
}

class _ExamResultItemState extends State<_ExamResultItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isCorrect ? AppConfig.correctColor : AppConfig.wrongColor;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index}',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.questionText.length > 40
                        ? '${widget.question.questionText.substring(0, 40)}...'
                        : widget.question.questionText,
                    style: const TextStyle(
                        color: Color(0xFFD4D4D4), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  widget.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(left: 8, right: 8),
            decoration: BoxDecoration(
              color: AppConfig.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConfig.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: '내 답',
                  value: widget.userAnswer.isEmpty ? '(미입력)' : widget.userAnswer,
                  color: widget.isCorrect ? AppConfig.correctColor : AppConfig.wrongColor,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: '정답',
                  value: widget.question.answer,
                  color: AppConfig.correctColor,
                ),
                const SizedBox(height: 10),
                Text(
                  '해설',
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.question.explanation,
                  style: const TextStyle(
                    color: Color(0xFFD4D4D4),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                value: total > 0 ? current / total : 0,
                backgroundColor: AppConfig.borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppConfig.primaryColor),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTextField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSubmitted;

  const _AnswerTextField(
      {required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '정답을 입력하세요',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: AppConfig.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppConfig.primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton(
      {required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConfig.cardColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: AppConfig.borderColor),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class _PassFailBadge extends StatelessWidget {
  final bool passed;

  const _PassFailBadge({required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppConfig.correctColor : AppConfig.wrongColor;
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          passed ? '합격' : '불합격',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int correct;
  final int total;
  final String timeTaken;
  final bool passed;

  const _ScoreCard(
      {required this.correct,
      required this.total,
      required this.timeTaken,
      required this.passed});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '소요 시간: $timeTaken',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? '합격 기준(60%)을 통과했습니다!'
                : '합격 기준(60% = ${(total * 0.6).ceil()}문제)에 미달했습니다.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TypeBreakdown extends StatelessWidget {
  final Map<String, int> typeTotal;
  final Map<String, int> typeCorrect;

  const _TypeBreakdown(
      {required this.typeTotal, required this.typeCorrect});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            final label = AppConfig.questionTypeLabels[type] ?? type;
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
                      Icon(icon, size: 16, color: Colors.grey[400]),
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
    );
  }
}

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
        border: Border.all(
            color: accentColor.withValues(alpha: 0.5), width: 1.5),
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
