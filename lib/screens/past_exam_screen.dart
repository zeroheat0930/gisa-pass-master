import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/question.dart';
import '../services/database_service.dart';
import '../widgets/question_card.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class PastExamScreen extends StatefulWidget {
  final DatabaseService db;

  const PastExamScreen({super.key, required this.db});

  @override
  State<PastExamScreen> createState() => _PastExamScreenState();
}

class _PastExamScreenState extends State<PastExamScreen> {
  bool _isLoading = false;
  String? _error;

  // 난이도 필터: null = 전체
  static const List<_DifficultyOption> _difficultyOptions = [
    _DifficultyOption(label: '전체', minDiff: null, maxDiff: null),
    _DifficultyOption(label: '쉬움', minDiff: 1, maxDiff: 2),
    _DifficultyOption(label: '보통', minDiff: 3, maxDiff: 3),
    _DifficultyOption(label: '어려움', minDiff: 4, maxDiff: 5),
  ];

  int _selectedDifficulty = 0; // index into _difficultyOptions

  static const List<_CategoryInfo> _categories = [
    _CategoryInfo(
      title: '코드 분석',
      subtitle: 'C / Java / Python',
      icon: Icons.code,
      color: AppConfig.primaryColor,
      type: 'code_reading',
    ),
    _CategoryInfo(
      title: 'SQL',
      subtitle: '데이터베이스 쿼리',
      icon: Icons.storage,
      color: Color(0xFF26A69A),
      type: 'sql',
    ),
    _CategoryInfo(
      title: '단답형',
      subtitle: '개념 / 용어',
      icon: Icons.edit_note,
      color: Color(0xFFFFB74D),
      type: 'short_answer',
    ),
    _CategoryInfo(
      title: '전체 혼합',
      subtitle: '모든 유형 랜덤',
      icon: Icons.shuffle,
      color: Color(0xFFE53935),
      type: null, // null = 전체
    ),
  ];

  Future<void> _loadAndStart({String? type, required String title}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final diff = _difficultyOptions[_selectedDifficulty];
      final questions = await widget.db.getQuestionsByTypeAndDifficulty(
        type,
        minDifficulty: diff.minDiff,
        maxDifficulty: diff.maxDiff,
        limit: 20,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('해당 조건에 맞는 문제가 없습니다.'),
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
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          'AI 문제은행',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 전체 랜덤 20문제 버튼
                  _GlobalRandomButton(
                    onTap: () => _loadAndStart(
                      type: null,
                      title: '전체 랜덤 20문제',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 난이도 필터
                  const Text(
                    '난이도',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_difficultyOptions.length, (i) {
                      final opt = _difficultyOptions[i];
                      final selected = _selectedDifficulty == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(opt.label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedDifficulty = i),
                          selectedColor:
                              AppConfig.primaryColor.withValues(alpha: 0.25),
                          backgroundColor: AppConfig.cardColor,
                          side: BorderSide(
                            color: selected
                                ? AppConfig.primaryColor
                                : AppConfig.borderColor,
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppConfig.primaryColor
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // 유형별 카드
                  const Text(
                    '유형별 문제',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _CategoryCard(
                        info: cat,
                        onTap: () => _loadAndStart(
                          type: cat.type,
                          title: '${cat.title} 20문제',
                        ),
                      );
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '오류: $_error',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppConfig.primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _DifficultyOption {
  final String label;
  final int? minDiff;
  final int? maxDiff;

  const _DifficultyOption({
    required this.label,
    required this.minDiff,
    required this.maxDiff,
  });
}

class _CategoryInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? type; // null = 전체

  const _CategoryInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });
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

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _CategoryInfo info;
  final VoidCallback onTap;

  const _CategoryCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppConfig.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConfig.borderColor),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(info.icon, color: info.color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              info.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              info.subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
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
