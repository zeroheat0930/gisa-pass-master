import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/stats_provider.dart';
import '../models/study_stats.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();
    final stats = statsProvider.stats;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: const Text(
          '학습 통계',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<StatsProvider>().loadStats(),
          ),
        ],
      ),
      body: statsProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppConfig.primaryColor),
            )
          : _StatsBody(stats: stats),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final StudyStats stats;

  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall accuracy circular indicator
          _OverallAccuracyCard(stats: stats),
          const SizedBox(height: 16),

          // Today's stats
          _TodayStatsCard(stats: stats),
          const SizedBox(height: 16),

          // Subject accuracy breakdown
          if (stats.subjectAccuracy.isNotEmpty) ...[
            _BreakdownCard(
              title: '과목별 정답률',
              icon: Icons.school,
              data: stats.subjectAccuracy,
            ),
            const SizedBox(height: 16),
          ],

          // Type accuracy breakdown
          if (stats.typeAccuracy.isNotEmpty) ...[
            _BreakdownCard(
              title: '유형별 정답률',
              icon: Icons.category,
              data: stats.typeAccuracy,
              labelMap: const {
                'code_reading': '코드 분석',
                'sql': 'SQL',
                'short_answer': '단답형',
              },
            ),
            const SizedBox(height: 16),
          ],

          // Streak
          if (stats.streakDays > 0) _StreakCard(days: stats.streakDays),
        ],
      ),
    );
  }
}

class _OverallAccuracyCard extends StatelessWidget {
  final StudyStats stats;

  const _OverallAccuracyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final accuracy = stats.totalAccuracy;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        children: [
          const Text(
            '전체 정답률',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: accuracy / 100,
                  strokeWidth: 12,
                  backgroundColor: AppConfig.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _accuracyColor(accuracy),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${accuracy.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _accuracyColor(accuracy),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${stats.totalCorrect}/${stats.totalSolved}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '총 ${stats.totalSolved}문제 풀이 완료',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _accuracyColor(double acc) {
    if (acc >= 80) return AppConfig.correctColor;
    if (acc >= 60) return const Color(0xFFFFC107);
    return AppConfig.primaryColor;
  }
}

class _TodayStatsCard extends StatelessWidget {
  final StudyStats stats;

  const _TodayStatsCard({required this.stats});

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
          const Row(
            children: [
              Icon(Icons.today, color: Color(0xFF569CD6), size: 20),
              SizedBox(width: 8),
              Text(
                '오늘의 학습',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: '풀이 수',
                  value: '${stats.todaySolved}',
                  unit: '문제',
                  color: const Color(0xFF569CD6),
                ),
              ),
              Container(
                  width: 1, height: 48, color: AppConfig.borderColor),
              Expanded(
                child: _StatTile(
                  label: '정답률',
                  value: stats.todayAccuracy.toStringAsFixed(1),
                  unit: '%',
                  color: AppConfig.correctColor,
                ),
              ),
              Container(
                  width: 1, height: 48, color: AppConfig.borderColor),
              Expanded(
                child: _StatTile(
                  label: '정답 수',
                  value: '${stats.todayCorrect}',
                  unit: '개',
                  color: const Color(0xFFFFC107),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: unit,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, double> data;
  final Map<String, String>? labelMap;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.data,
    this.labelMap,
  });

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
          Row(
            children: [
              Icon(icon, color: AppConfig.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...data.entries.map((entry) {
            final displayLabel =
                labelMap?[entry.key] ?? entry.key;
            final accuracy = entry.value.clamp(0.0, 100.0);
            final barColor = accuracy >= 80
                ? AppConfig.correctColor
                : accuracy >= 60
                    ? const Color(0xFFFFC107)
                    : AppConfig.wrongColor;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayLabel,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${accuracy.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: barColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: accuracy / 100,
                      backgroundColor: AppConfig.borderColor,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 8,
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

class _StreakCard extends StatelessWidget {
  final int days;

  const _StreakCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppConfig.warningColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: AppConfig.warningColor, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$days일 연속 학습!',
                style: const TextStyle(
                  color: AppConfig.warningColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '꾸준함이 합격의 열쇠입니다',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
