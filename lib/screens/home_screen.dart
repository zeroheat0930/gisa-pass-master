import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/study_stats.dart';
import '../providers/study_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/dday_timer.dart';
import 'quiz_screen.dart';

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
              // App title
              Text(
                AppConfig.appTitle,
                style: const TextStyle(
                  color: AppConfig.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // D-Day timer
              const DdayTimer(),
              const SizedBox(height: 28),

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
            ],
          ),
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
