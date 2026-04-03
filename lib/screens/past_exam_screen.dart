import 'dart:async';
import 'package:flutter/material.dart';
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

class _PastExamScreenState extends State<PastExamScreen> {
  bool _isLoading = true;
  String? _error;
  List<Question> _allQuestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questions = await widget.loadQuestions();
      if (!mounted) return;
      setState(() {
        _allQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppConfig.primaryColor),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppConfig.backgroundColor,
          leading: const BackButton(color: Colors.white70),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            '문제를 불러오지 못했습니다.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return _YearSelectorScreen(allQuestions: _allQuestions);
  }
}

// ── Phase 1: Year / Round Selector ───────────────────────────────────────────

class _YearSelectorScreen extends StatefulWidget {
  final List<Question> allQuestions;

  const _YearSelectorScreen({required this.allQuestions});

  @override
  State<_YearSelectorScreen> createState() => _YearSelectorScreenState();
}

class _YearSelectorScreenState extends State<_YearSelectorScreen> {
  late final List<int> _years;
  static const List<int> _rounds = [1, 2, 3];

  int? _expandedYear;

  // 캐싱: 한번만 계산
  late final Map<String, List<Question>> _cache;
  late final Map<int, int> _yearCounts;

  @override
  void initState() {
    super.initState();
    _cache = {};
    _yearCounts = {};
    for (final q in widget.allQuestions) {
      final key = '${q.year}_${q.round}';
      _cache.putIfAbsent(key, () => []).add(q);
      _yearCounts[q.year] = (_yearCounts[q.year] ?? 0) + 1;
    }
    // Compute years that actually have questions
    _years = _yearCounts.keys.where((y) => (_yearCounts[y] ?? 0) > 0).toList()..sort();
    if (_years.isEmpty) _years = [2020, 2021, 2022, 2023, 2024, 2025];
  }

  List<Question> _forYearRound(int year, int round) =>
      _cache['${year}_$round'] ?? [];

  List<Question> _forYear(int year) =>
      widget.allQuestions.where((q) => q.year == year).toList();

  void _startQuiz(List<Question> questions, String title) {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 회차에 문제가 없습니다.'),
          backgroundColor: AppConfig.cardColor,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _QuizScreen(questions: questions, title: title),
      ),
    );
  }

  void _startRandom20(List<Question> pool, String title) {
    final shuffled = List<Question>.from(pool)..shuffle();
    final questions = shuffled.take(20).toList();
    _startQuiz(questions, title);
  }

  void _openReview(List<Question> questions, String title) {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('해당 회차에 문제가 없습니다.'),
          backgroundColor: AppConfig.cardColor,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReviewScreen(questions: questions, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          '기출문제',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Global random button
              _GlobalRandomButton(
                onTap: () => _startRandom20(
                  widget.allQuestions,
                  '전체 랜덤 20문제',
                ),
              ),
              const SizedBox(height: 24),

              // Year cards grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: _years.length,
                itemBuilder: (context, index) {
                  final year = _years[index];
                  final isExpanded = _expandedYear == year;
                  final count = _forYear(year).length;
                  return _YearCard(
                    year: year,
                    questionCount: count,
                    isExpanded: isExpanded,
                    onTap: () {
                      setState(() {
                        _expandedYear = isExpanded ? null : year;
                      });
                    },
                  );
                },
              ),

              // Expanded year rounds panel
              if (_expandedYear != null) ...[
                const SizedBox(height: 16),
                _RoundsPanel(
                  year: _expandedYear!,
                  rounds: _rounds,
                  questionsFor: _forYearRound,
                  onRandom20: (q, t) => _startRandom20(q, t),
                  onAll: (q, t) => _startQuiz(q, t),
                  onReview: (q, t) => _openReview(q, t),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Global random button ──────────────────────────────────────────────────────

class _GlobalRandomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlobalRandomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppConfig.primaryColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shuffle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              '전체 랜덤 20문제',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Year card ─────────────────────────────────────────────────────────────────

class _YearCard extends StatelessWidget {
  final int year;
  final int questionCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const _YearCard({
    required this.year,
    required this.questionCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isExpanded
              ? AppConfig.primaryColor.withValues(alpha: 0.15)
              : AppConfig.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? AppConfig.primaryColor
                : AppConfig.borderColor,
            width: isExpanded ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: isExpanded
                        ? AppConfig.primaryColor
                        : Colors.grey[500],
                  ),
                  const Spacer(),
                  if (isExpanded)
                    const Icon(
                      Icons.expand_less,
                      size: 18,
                      color: AppConfig.primaryColor,
                    )
                  else
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$year년',
                style: TextStyle(
                  color: isExpanded ? AppConfig.primaryColor : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                questionCount > 0
                    ? '$questionCount문제'
                    : '준비중',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rounds panel ──────────────────────────────────────────────────────────────

class _RoundsPanel extends StatelessWidget {
  final int year;
  final List<int> rounds;
  final List<Question> Function(int year, int round) questionsFor;
  final void Function(List<Question>, String) onRandom20;
  final void Function(List<Question>, String) onAll;
  final void Function(List<Question>, String) onReview;

  const _RoundsPanel({
    required this.year,
    required this.rounds,
    required this.questionsFor,
    required this.onRandom20,
    required this.onAll,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$year년 회차 선택',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...rounds.map((round) {
            final questions = questionsFor(year, round);
            final title = '$year년 $round회';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoundRow(
                title: title,
                questionCount: questions.length,
                onRandom20: () => onRandom20(questions, '$title 랜덤 20문제'),
                onAll: () => onAll(questions, '$title 전체'),
                onReview: () => onReview(questions, '$title 풀이 보기'),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Round row ─────────────────────────────────────────────────────────────────

class _RoundRow extends StatelessWidget {
  final String title;
  final int questionCount;
  final VoidCallback onRandom20;
  final VoidCallback onAll;
  final VoidCallback onReview;

  const _RoundRow({
    required this.title,
    required this.questionCount,
    required this.onRandom20,
    required this.onAll,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConfig.borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                questionCount > 0 ? '$questionCount문제' : '준비중',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: '랜덤 20문제',
                  icon: Icons.shuffle,
                  color: AppConfig.primaryColor,
                  onTap: onRandom20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '전체 풀기',
                  icon: Icons.play_arrow,
                  color: const Color(0xFF1565C0),
                  onTap: onAll,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '풀이 보기',
                  icon: Icons.menu_book_outlined,
                  color: const Color(0xFF2E7D32),
                  onTap: onReview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small action button ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phase 2: Quiz screen ──────────────────────────────────────────────────────

class _QuizScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;

  const _QuizScreen({required this.questions, required this.title});

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<_QuizScreen> {
  bool _isFinished = false;
  int _currentIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _showExplanation = false;

  final List<String> _userAnswers = [];
  final List<bool> _isCorrectList = [];

  late final Stopwatch _stopwatch;
  Timer? _timerTick;
  String _elapsedDisplay = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _stopwatch.elapsed;
      final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedDisplay = '$mm:$ss');
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timerTick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _submit() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    final question = widget.questions[_currentIndex];
    final correct =
        answer.toLowerCase().trim() == question.answer.toLowerCase().trim();
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
      _timerTick?.cancel();
      _stopwatch.stop();
      setState(() => _isFinished = true);
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _retry() {
    _timerTick?.cancel();
    _answerController.clear();
    _userAnswers.clear();
    _isCorrectList.clear();
    _stopwatch.reset();
    _stopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _stopwatch.elapsed;
      final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
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
    if (_isFinished) return _buildResultsScreen();
    return _buildQuizScreen();
  }

  Widget _buildQuizScreen() {
    final question = widget.questions[_currentIndex];
    final total = widget.questions.length;
    final current = _currentIndex + 1;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
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
                            borderSide: const BorderSide(
                                color: AppConfig.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppConfig.primaryColor, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppConfig.borderColor),
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
                          side: const BorderSide(
                              color: AppConfig.borderColor),
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

  Widget _buildResultsScreen() {
    final total = widget.questions.length;
    final correct = _isCorrectList.where((v) => v).length;
    final passed = correct >= (total * 0.6).ceil();

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
                    color: (passed
                            ? AppConfig.correctColor
                            : AppConfig.wrongColor)
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
                      final icon = AppConfig.questionTypeIcons[type] ??
                          Icons.help_outline;
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
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
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

// ── Phase 3: Review screen ────────────────────────────────────────────────────

class _ReviewScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;

  const _ReviewScreen({required this.questions, required this.title});

  @override
  State<_ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<_ReviewScreen> {
  late final List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = List.filled(widget.questions.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              final allExpanded = _expanded.every((v) => v);
              setState(() {
                for (int i = 0; i < _expanded.length; i++) {
                  _expanded[i] = !allExpanded;
                }
              });
            },
            child: Text(
              _expanded.every((v) => v) ? '모두 접기' : '모두 펼치기',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.questions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final question = widget.questions[index];
            final isExpanded = _expanded[index];
            return _ReviewCard(
              index: index,
              question: question,
              isExpanded: isExpanded,
              onToggle: () {
                setState(() => _expanded[index] = !_expanded[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final Question question;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppConfig.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? AppConfig.primaryColor.withValues(alpha: 0.5)
                : AppConfig.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed header always visible
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppConfig.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      question.questionText,
                      style: const TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ],
              ),
            ),

            // Expanded content
            if (isExpanded) ...[
              Divider(
                  color: AppConfig.borderColor,
                  height: 1,
                  thickness: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionCard(question: question),
                    const SizedBox(height: 16),
                    // Answer section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppConfig.correctColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppConfig.correctColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppConfig.correctColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '정답',
                                  style: TextStyle(
                                    color: AppConfig.correctColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  question.answer,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Explanation section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppConfig.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppConfig.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  color: Colors.amber[400], size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '해설',
                                style: TextStyle(
                                  color: Colors.amber[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question.explanation,
                            style: const TextStyle(
                              color: Color(0xFFD4D4D4),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared supporting widgets ─────────────────────────────────────────────────

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
            _InfoRow(
                label: '내 답', value: userAnswer, color: Colors.grey),
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
