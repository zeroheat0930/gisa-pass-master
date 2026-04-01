import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/study_stats.dart';
import '../providers/study_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/dday_timer.dart';
import 'quiz_screen.dart';
import 'ai_prediction_screen.dart';
import 'subscription_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadStats();
    });
  }

  void _startMode(BuildContext context, StudyMode mode, {String? subType}) {
    final provider = context.read<StudyProvider>();
    Future<void> loader;
    if (mode == StudyMode.wrongAnswer) {
      loader = provider.loadWrongAnswerQuestions();
    } else if (mode == StudyMode.byType && subType != null) {
      loader = provider.loadQuestionsByType(subType);
    } else {
      loader = provider.loadQuestions();
    }
    loader.then((_) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(mode: mode),
        ),
      );
    });
  }

  void _startAiPrediction(BuildContext context) async {
    final provider = context.read<StudyProvider>();
    await provider.loadQuestions();
    if (!context.mounted) return;

    final questions = provider.questionList;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제가 없습니다.')),
      );
      return;
    }

    // AI 예측 모의고사: 최대 20문제 선별
    final examQuestions = questions.take(20).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiPredictionScreen(questions: examQuestions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>().stats;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: title + premium button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Text(
                    '기사패스마스터',
                    style: TextStyle(
                      color: AppConfig.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // D-Day timer
              const DdayTimer(),
              const SizedBox(height: 24),

              // AI 예측 모의고사 (가장 눈에 띄는 버튼)
              _AiPredictionButton(
                onTap: () => _startAiPrediction(context),
              ),
              const SizedBox(height: 12),

              // Primary: 예측 학습
              _ModeButton(
                label: '예측 학습 시작',
                icon: Icons.auto_awesome,
                color: AppConfig.primaryColor,
                subtitle: 'AI가 자주 나오는 문제를 선별합니다',
                onTap: () => _startMode(context, StudyMode.prediction),
              ),
              const SizedBox(height: 12),

              // Warning: 스파르타 오답노트
              _ModeButton(
                label: '스파르타 오답노트',
                icon: Icons.local_fire_department,
                color: AppConfig.warningColor,
                subtitle: '틀린 문제를 반복 학습합니다',
                onTap: () => _startMode(context, StudyMode.wrongAnswer),
              ),
              const SizedBox(height: 20),

              // 유형별 학습 section
              const Text(
                '유형별 학습',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: '코드 분석',
                      icon: Icons.code,
                      color: const Color(0xFF569CD6),
                      onTap: () => _startMode(
                        context,
                        StudyMode.byType,
                        subType: 'code_reading',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TypeButton(
                      label: 'SQL',
                      icon: Icons.storage,
                      color: const Color(0xFFCE9178),
                      onTap: () => _startMode(
                        context,
                        StudyMode.byType,
                        subType: 'sql',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TypeButton(
                      label: '단답형',
                      icon: Icons.edit_note,
                      color: AppConfig.correctColor,
                      onTap: () => _startMode(
                        context,
                        StudyMode.byType,
                        subType: 'short_answer',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Quick stats
              _QuickStats(stats: stats),
              const SizedBox(height: 20),

              // 개발자 메시지 + 광고 제거 유도
              _DevMessageCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiPredictionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AiPredictionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI 실전 모의고사',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8),
                        _AiBadge(),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'AI가 기출 패턴을 분석하여 실시간 출제',
                      style: TextStyle(
                        color: Colors.white70,
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
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final StudyStats stats;

  const _QuickStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final todaySolved = stats.todaySolved;
    final todayAccuracy = stats.todayAccuracy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.borderColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: '오늘 풀이 수',
              value: '$todaySolved문제',
              icon: Icons.check_circle_outline,
              color: AppConfig.correctColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppConfig.borderColor,
          ),
          Expanded(
            child: _StatItem(
              label: '정답률',
              value: '${todayAccuracy.toStringAsFixed(1)}%',
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF569CD6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
      ],
    );
  }
}

class _DevMessageCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DevMessageCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF2A3A4A),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.coffee,
                    color: Color(0xFF2196F3),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '개발자의 한마디',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '안녕하세요! 저도 정보처리기사 준비하면서 급하게 만든 앱입니다. '
              '혹시 광고가 거슬리시다면... 커피 한 잔 값으로 광고 없이 '
              '공부에만 집중할 수 있어요 ☕',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                '광고 제거하고 공부에 집중하기 →',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
