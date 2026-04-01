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
          : _StatsDashboard(stats: stats),
    );
  }
}

// ─────────────────────────────────────────────
// Main scrollable dashboard
// ─────────────────────────────────────────────

class _StatsDashboard extends StatelessWidget {
  final StudyStats stats;

  const _StatsDashboard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 오늘의 학습
          _SectionHeader(icon: Icons.today, label: '오늘의 학습'),
          const SizedBox(height: 8),
          _TodayStudyCard(stats: stats),
          const SizedBox(height: 20),

          // 2. 전체 학습 현황
          _SectionHeader(icon: Icons.bar_chart, label: '전체 학습 현황'),
          const SizedBox(height: 8),
          _OverallProgressCard(stats: stats),
          const SizedBox(height: 20),

          // 3. 유형별 분석
          _SectionHeader(icon: Icons.category, label: '유형별 분석'),
          const SizedBox(height: 8),
          _TypeAnalysisCard(stats: stats),
          const SizedBox(height: 20),

          // 4. 과목별 분석
          _SectionHeader(icon: Icons.school, label: '과목별 분석'),
          const SizedBox(height: 8),
          _SubjectAnalysisCard(stats: stats),
          const SizedBox(height: 20),

          // 5. 난이도별 분석
          _SectionHeader(icon: Icons.star, label: '난이도별 분석'),
          const SizedBox(height: 8),
          _DifficultyAnalysisCard(stats: stats),
          const SizedBox(height: 20),

          // 6. 약점 분석
          _SectionHeader(
            icon: Icons.warning_amber_rounded,
            label: '약점 분석',
            color: const Color(0xFFE53935),
          ),
          const SizedBox(height: 8),
          _WeaknessCard(stats: stats),
          const SizedBox(height: 20),

          // 7. 학습 추이
          _SectionHeader(icon: Icons.timeline, label: '학습 추이 (최근 7일)'),
          const SizedBox(height: 8),
          _LearningTrendCard(stats: stats),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared: section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF569CD6),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared: card container
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AppConfig.borderColor,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// Section 1: 오늘의 학습
// ─────────────────────────────────────────────

class _TodayStudyCard extends StatelessWidget {
  final StudyStats stats;

  const _TodayStudyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final accuracy = stats.todayAccuracy;
    final accColor = _accuracyColor(accuracy);

    return _Card(
      child: Row(
        children: [
          // Circular accuracy indicator
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: accuracy / 100,
                  strokeWidth: 10,
                  backgroundColor: AppConfig.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(accColor),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${accuracy.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: accColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '정답률',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: '풀이 수',
                  value: '${stats.todaySolved}',
                  unit: '문제',
                  color: const Color(0xFF569CD6),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: '정답 수',
                  value: '${stats.todayCorrect}',
                  unit: '개',
                  color: AppConfig.correctColor,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: '연속 학습',
                  value: '${stats.streakDays}',
                  unit: '일',
                  color: AppConfig.warningColor,
                  icon: Icons.local_fire_department,
                ),
              ],
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
  final String unit;
  final Color color;
  final IconData? icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const Spacer(),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Section 2: 전체 학습 현황
// ─────────────────────────────────────────────

class _OverallProgressCard extends StatelessWidget {
  final StudyStats stats;

  const _OverallProgressCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final accuracy = stats.totalAccuracy;
    final accColor = _accuracyColor(accuracy);
    final completion = stats.completionRate;

    return _Card(
      child: Column(
        children: [
          // Top row: three stat tiles
          Row(
            children: [
              _BigStatTile(
                label: '총 풀이',
                value: '${stats.totalSolved}',
                unit: '문제',
                color: const Color(0xFF569CD6),
              ),
              _VerticalDivider(),
              _BigStatTile(
                label: '총 정답',
                value: '${stats.totalCorrect}',
                unit: '개',
                color: AppConfig.correctColor,
              ),
              _VerticalDivider(),
              _BigStatTile(
                label: '정답률',
                value: accuracy.toStringAsFixed(1),
                unit: '%',
                color: accColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Completion progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '전체 문제 완료율',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${stats.totalSolved} / ${stats.totalAvailable}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: completion,
                  backgroundColor: AppConfig.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF569CD6),
                  ),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(completion * 100).toStringAsFixed(1)}% 완료',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _BigStatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 12,
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
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 52, color: AppConfig.borderColor);
  }
}

// ─────────────────────────────────────────────
// Section 3: 유형별 분석
// ─────────────────────────────────────────────

class _TypeAnalysisCard extends StatelessWidget {
  final StudyStats stats;

  const _TypeAnalysisCard({required this.stats});

  static const Map<String, String> _labels = {
    'code_reading': '코드 분석',
    'sql': 'SQL',
    'short_answer': '단답형',
  };

  @override
  Widget build(BuildContext context) {
    final orderedKeys = ['code_reading', 'sql', 'short_answer'];

    return _Card(
      child: Column(
        children: orderedKeys.map((key) {
          final label = _labels[key] ?? key;
          final accuracy = stats.typeAccuracy[key] ?? 0;
          final solved = stats.typeSolved[key] ?? 0;
          return _AnalysisBar(
            label: label,
            accuracy: accuracy,
            solved: solved,
            isLast: key == orderedKeys.last,
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 4: 과목별 분석
// ─────────────────────────────────────────────

class _SubjectAnalysisCard extends StatelessWidget {
  final StudyStats stats;

  const _SubjectAnalysisCard({required this.stats});

  static const List<String> _orderedSubjects = [
    '프로그래밍',
    'SQL',
    '네트워크',
    '소프트웨어공학',
    '데이터베이스',
    '보안',
  ];

  @override
  Widget build(BuildContext context) {
    // Show ordered subjects first, then any extra subjects from data
    final keys = [
      ..._orderedSubjects.where(
        (s) =>
            stats.subjectAccuracy.containsKey(s) ||
            stats.subjectSolved.containsKey(s),
      ),
      ...stats.subjectAccuracy.keys.where(
        (s) => !_orderedSubjects.contains(s),
      ),
    ];

    if (keys.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '아직 풀이 데이터가 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        children: keys.map((key) {
          final accuracy = stats.subjectAccuracy[key] ?? 0;
          final solved = stats.subjectSolved[key] ?? 0;
          return _AnalysisBar(
            label: key,
            accuracy: accuracy,
            solved: solved,
            isLast: key == keys.last,
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared: horizontal bar row
// ─────────────────────────────────────────────

class _AnalysisBar extends StatelessWidget {
  final String label;
  final double accuracy;
  final int solved;
  final bool isLast;

  const _AnalysisBar({
    required this.label,
    required this.accuracy,
    required this.solved,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = accuracy.clamp(0.0, 100.0);
    final barColor = _accuracyColor(clamped);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$solved문제',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                child: Text(
                  '${clamped.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: solved > 0 ? clamped / 100 : 0,
              backgroundColor: AppConfig.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 5: 난이도별 분석
// ─────────────────────────────────────────────

class _DifficultyAnalysisCard extends StatelessWidget {
  final StudyStats stats;

  const _DifficultyAnalysisCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: List.generate(5, (i) {
          final level = i + 1;
          final accuracy = stats.difficultyAccuracy[level] ?? 0;
          final clamped = accuracy.clamp(0.0, 100.0);
          final barColor = _accuracyColor(clamped);
          final hasData = stats.difficultyAccuracy.containsKey(level);

          return Padding(
            padding: EdgeInsets.only(bottom: level == 5 ? 0 : 12),
            child: Row(
              children: [
                // Stars
                SizedBox(
                  width: 80,
                  child: Row(
                    children: List.generate(
                      5,
                      (s) => Icon(
                        s < level ? Icons.star : Icons.star_border,
                        color: s < level
                            ? const Color(0xFFFFC107)
                            : Colors.grey[700],
                        size: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: hasData ? clamped / 100 : 0,
                      backgroundColor: AppConfig.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasData ? barColor : Colors.grey[800]!,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  child: Text(
                    hasData ? '${clamped.toStringAsFixed(1)}%' : '-',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: hasData ? barColor : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 6: 약점 분석
// ─────────────────────────────────────────────

class _WeaknessCard extends StatelessWidget {
  final StudyStats stats;

  const _WeaknessCard({required this.stats});

  List<_WeakArea> _computeWeakAreas() {
    final areas = <_WeakArea>[];

    stats.subjectAccuracy.forEach((subject, acc) {
      final solved = stats.subjectSolved[subject] ?? 0;
      if (solved > 0) {
        areas.add(_WeakArea(label: subject, accuracy: acc, kind: '과목'));
      }
    });

    const typeLabels = {
      'code_reading': '코드 분석',
      'sql': 'SQL',
      'short_answer': '단답형',
    };
    stats.typeAccuracy.forEach((type, acc) {
      final solved = stats.typeSolved[type] ?? 0;
      if (solved > 0) {
        areas.add(_WeakArea(
          label: typeLabels[type] ?? type,
          accuracy: acc,
          kind: '유형',
        ));
      }
    });

    areas.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return areas.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final weak = _computeWeakAreas();

    if (weak.isEmpty) {
      return _Card(
        borderColor: AppConfig.primaryColor.withValues(alpha: 0.3),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '아직 분석할 데이터가 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ),
      );
    }

    return _Card(
      borderColor: AppConfig.primaryColor.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppConfig.primaryColor, size: 16),
              const SizedBox(width: 6),
              Text(
                '집중 학습이 필요한 영역',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...weak.asMap().entries.map((entry) {
            final idx = entry.key;
            final area = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: idx < weak.length - 1 ? 12 : 0),
              child: _WeaknessItem(area: area, rank: idx + 1),
            );
          }),
        ],
      ),
    );
  }
}

class _WeakArea {
  final String label;
  final double accuracy;
  final String kind;

  _WeakArea({required this.label, required this.accuracy, required this.kind});
}

class _WeaknessItem extends StatelessWidget {
  final _WeakArea area;
  final int rank;

  const _WeaknessItem({required this.area, required this.rank});

  @override
  Widget build(BuildContext context) {
    final clamped = area.accuracy.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppConfig.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: AppConfig.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      area.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppConfig.borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        area.kind,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '집중 학습 권장 · 현재 정답률 ${clamped.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${clamped.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppConfig.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 7: 학습 추이
// ─────────────────────────────────────────────

class _LearningTrendCard extends StatelessWidget {
  final StudyStats stats;

  const _LearningTrendCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.last7Days.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '최근 7일 학습 데이터가 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        children: [
          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '날짜',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '정답률',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '풀이',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '정답률',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppConfig.borderColor, height: 1),
          const SizedBox(height: 10),
          ...stats.last7Days.asMap().entries.map((entry) {
            final idx = entry.key;
            final day = entry.value;
            final acc = day.accuracy;
            final barColor = _accuracyColor(acc);
            final isLast = idx == stats.last7Days.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      day.displayDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: day.solved > 0 ? acc / 100 : 0,
                        backgroundColor: AppConfig.borderColor,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${day.solved}문제',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      day.solved > 0
                          ? '${acc.toStringAsFixed(0)}%'
                          : '-',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: day.solved > 0 ? barColor : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

// ─────────────────────────────────────────────
// Shared utility
// ─────────────────────────────────────────────

Color _accuracyColor(double acc) {
  if (acc >= 70) return AppConfig.correctColor;
  if (acc >= 50) return const Color(0xFFFFC107);
  return AppConfig.primaryColor;
}
