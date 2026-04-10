import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/study_provider.dart';
import '../widgets/question_card.dart';
import '../widgets/answer_effect.dart';

class QuizScreen extends StatefulWidget {
  final StudyMode mode;
  final int? planDayNumber;

  const QuizScreen({super.key, required this.mode, this.planDayNumber});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _showExplanation = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit(StudyProvider provider) async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    await provider.submitAnswer(answer);

    if (!mounted) return;
    if (!provider.isAnswered) return;

    // 정답/오답 햅틱 피드백
    if (provider.isCorrect) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // 광고 표시 (5문제마다)
    if (provider.shouldShowAd) {
      provider.clearAdFlag();
    }

    AnswerEffectOverlay.show(
      context,
      isCorrect: provider.isCorrect,
      onComplete: () {
        if (mounted) {
          setState(() => _showExplanation = true);
        }
      },
    );
  }

  void _next(StudyProvider provider) {
    _answerController.clear();
    setState(() => _showExplanation = false);
    provider.nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudyProvider>();

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(color: AppConfig.primaryColor),
        ),
      );
    }

    if (provider.questionList.isEmpty) {
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _buildAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                '문제가 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '돌아가기',
                  style: TextStyle(color: AppConfig.primaryColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = provider.currentQuestion;
    if (question == null) {
      final daysLeft = AppConfig.examDate.difference(DateTime.now()).inDays;
      return Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _buildAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration,
                  color: AppConfig.correctColor, size: 72),
              const SizedBox(height: 16),
              const Text(
                '모든 문제를 완료했습니다!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              if (provider.maxCombo >= 2) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Color(0xFFFF6D00), size: 24),
                    const SizedBox(width: 6),
                    Text(
                      '최대 콤보: ${provider.maxCombo}연속 정답!',
                      style: const TextStyle(
                        color: Color(0xFFFF6D00),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppConfig.primaryColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  daysLeft > 0
                      ? '시험까지 D-$daysLeft! 포기하지 마세요!'
                      : '시험 당일! 최선을 다하세요!',
                  style: TextStyle(
                    color: daysLeft <= 7
                        ? AppConfig.primaryColor
                        : Colors.grey[300],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (widget.planDayNumber != null) {
                    final totalSolved = provider.questionList.length;
                    final totalCorrect = provider.questionList
                        .where((q) => q.id != null)
                        .length; // approximate
                    Navigator.pop(context, {
                      'solved': totalSolved,
                      'correct': totalCorrect,
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                ),
                child: Text(widget.planDayNumber != null ? '미션 완료' : '홈으로'),
              ),
            ],
          ),
        ),
      );
    }

    final total = provider.questionList.length;
    final current = provider.questionIndex + 1;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: _buildAppBar(context),
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

            // 콤보 카운터
            if (provider.comboCount >= 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department,
                        color: provider.comboCount >= 5
                            ? const Color(0xFFFF6D00)
                            : const Color(0xFFFFB74D),
                        size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.comboCount} COMBO!',
                      style: TextStyle(
                        color: provider.comboCount >= 5
                            ? const Color(0xFFFF6D00)
                            : const Color(0xFFFFB74D),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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
                    // Question card
                    QuestionCard(question: question),
                    const SizedBox(height: 20),

                    // Answer input
                    if (!provider.isAnswered) ...[
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
                        onSubmitted: (_) => _submit(provider),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () => _submit(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
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
                    if (_showExplanation && provider.isAnswered) ...[
                      const SizedBox(height: 16),
                      _ExplanationCard(
                        isCorrect: provider.isCorrect,
                        correctAnswer: question.answer,
                        userAnswer: provider.userAnswer,
                        explanation: question.explanation,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _next(provider),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('다음 문제'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.cardColor,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
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

  AppBar _buildAppBar(BuildContext context) {
    String title;
    switch (widget.mode) {
      case StudyMode.prediction:
        title = '예측 학습';
        break;
      case StudyMode.wrongAnswer:
        title = '스파르타 오답노트';
        break;
      case StudyMode.byType:
        title = '유형별 학습';
        break;
      case StudyMode.bookmark:
        title = '즐겨찾기 복습';
        break;
    }
    final provider = context.read<StudyProvider>();
    final question = provider.currentQuestion;

    return AppBar(
      backgroundColor: AppConfig.backgroundColor,
      foregroundColor: Colors.white,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
      elevation: 0,
      actions: [
        if (question != null && question.id != null)
          FutureBuilder<bool>(
            future: provider.isBookmarked(question.id!),
            builder: (context, snapshot) {
              final isBookmarked = snapshot.data ?? false;
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? const Color(0xFFFFD700)
                      : Colors.grey[500],
                ),
                onPressed: () async {
                  await provider.toggleBookmark(question.id!);
                  if (context.mounted) setState(() {});
                },
              );
            },
          ),
      ],
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
    final accentColor = isCorrect
        ? AppConfig.correctColor
        : AppConfig.wrongColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
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
            style: TextStyle(
                color: Colors.grey[500], fontSize: 13),
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
