import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/study_provider.dart';
import '../widgets/question_card.dart';
import '../widgets/answer_effect.dart';

class WrongAnswerScreen extends StatefulWidget {
  const WrongAnswerScreen({super.key});

  @override
  State<WrongAnswerScreen> createState() => _WrongAnswerScreenState();
}

class _WrongAnswerScreenState extends State<WrongAnswerScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _showExplanation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().loadWrongAnswerQuestions();
    });
  }

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

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          '스파르타 오답노트 🔥',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: _buildBody(context, provider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, StudyProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppConfig.warningColor),
      );
    }

    // No due questions
    if (provider.questionList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events,
                  color: AppConfig.correctColor, size: 80),
              const SizedBox(height: 24),
              const Text(
                '복습할 문제가 없습니다!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                '잘하고 있어요!',
                style: TextStyle(
                  color: AppConfig.correctColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '오답 문제가 쌓이면 여기서 복습할 수 있습니다.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppConfig.borderColor),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('홈으로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    final question = provider.currentQuestion;
    if (question == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.military_tech,
                color: AppConfig.warningColor, size: 80),
            const SizedBox(height: 20),
            const Text(
              '오늘의 복습 완료!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.warningColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('홈으로',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final total = provider.questionList.length;
    final current = provider.questionIndex + 1;

    return Column(
      children: [
        // Header with count
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppConfig.warningColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppConfig.warningColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: AppConfig.warningColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '복습 문제 $total개',
                style: const TextStyle(
                  color: AppConfig.warningColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $total',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              backgroundColor: AppConfig.borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppConfig.warningColor,
              ),
              minHeight: 6,
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionCard(question: question),
                const SizedBox(height: 20),

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
                        borderSide:
                            const BorderSide(color: Color(0xFF3C3C3C)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppConfig.warningColor, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF3C3C3C)),
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
                      backgroundColor: AppConfig.warningColor,
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

                if (_showExplanation && provider.isAnswered) ...[
                  const SizedBox(height: 16),
                  _WrongAnswerExplanationCard(
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppConfig.borderColor),
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
    );
  }
}

class _WrongAnswerExplanationCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String userAnswer;
  final String explanation;

  const _WrongAnswerExplanationCard({
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text('내 답:',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                ),
                Expanded(
                  child: Text(
                    userAnswer,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text('정답:',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13)),
                ),
                Expanded(
                  child: Text(
                    correctAnswer,
                    style: const TextStyle(
                      color: AppConfig.correctColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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
