import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/study_plan.dart';
import '../providers/study_provider.dart';
import '../services/study_plan_service.dart';
import '../services/purchase_service.dart';
import 'quiz_screen.dart';
import 'subscription_screen.dart';

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyPlanService>().loadCurrentPlan();
    });
  }

  Future<void> _startNewPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConfig.cardColor,
        title: const Text('14일 합격 플랜 시작',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          '오늘부터 14일간의 체계적인 학습 플랜을 시작합니다.\n매일 주어진 미션을 완료하면 합격에 한 걸음 더 가까워집니다!',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('시작하기!',
                style: TextStyle(
                    color: AppConfig.primaryColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<StudyPlanService>().startNewPlan();
    }
  }

  Future<void> _startDayMission(int dayNumber) async {
    final planService = context.read<StudyPlanService>();
    final purchaseService = context.read<PurchaseService>();

    // 프리미엄 체크: Day 4부터 프리미엄 필요
    if (dayNumber > 3 && !purchaseService.isPremium) {
      if (!mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    setState(() => _loading = true);
    final questions = await planService.getQuestionsForDay(dayNumber);
    setState(() => _loading = false);

    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('문제가 없습니다. 먼저 다른 모드로 문제를 풀어보세요.'),
          backgroundColor: AppConfig.cardColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // StudyProvider에 문제 세팅 후 퀴즈 시작
    final provider = context.read<StudyProvider>();
    provider.setQuestions(questions);

    final result = await Navigator.push<Map<String, int>>(
      context,
      CupertinoPageRoute(
        builder: (_) => QuizScreen(
          mode: StudyMode.prediction,
          planDayNumber: dayNumber,
        ),
      ),
    );

    if (result != null && mounted) {
      await planService.completeDay(
        dayNumber,
        result['solved'] ?? 0,
        result['correct'] ?? 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final planService = context.watch<StudyPlanService>();
    final plan = planService.currentPlan;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '14일 합격 플랜',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (plan != null)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey[500], size: 20),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppConfig.cardColor,
                    title: const Text('플랜 초기화',
                        style: TextStyle(color: Colors.white)),
                    content: const Text('진행 중인 플랜을 초기화하고 새로 시작하시겠습니까?',
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('취소',
                            style: TextStyle(color: Colors.grey[400])),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('초기화',
                            style: TextStyle(color: AppConfig.wrongColor)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await planService.resetPlan();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppConfig.primaryColor))
          : plan == null
              ? _NoPlanView(onStart: _startNewPlan)
              : _PlanTimelineView(
                  plan: plan,
                  progressMap: planService.progressMap,
                  completedDays: planService.completedDays,
                  onDayTap: _startDayMission,
                ),
    );
  }
}

// ─── No Plan View ───────────────────────────────────────────────────────────

class _NoPlanView extends StatelessWidget {
  final VoidCallback onStart;

  const _NoPlanView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month,
                color: AppConfig.primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '14일 합격 플랜',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '시험까지 14일!\n매일 체계적인 미션을 따라가면\n합격이 보입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppConfig.primaryColor,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onStart,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '오늘부터 시작하기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan Timeline View ─────────────────────────────────────────────────────

class _PlanTimelineView extends StatelessWidget {
  final StudyPlan plan;
  final Map<int, DailyProgress> progressMap;
  final int completedDays;
  final ValueChanged<int> onDayTap;

  const _PlanTimelineView({
    required this.plan,
    required this.progressMap,
    required this.completedDays,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final todayDay = plan.todayDay.clamp(1, 14);
    final isPremium = context.watch<PurchaseService>().isPremium;

    return Column(
      children: [
        // 진행률 헤더
        _ProgressHeader(
          completedDays: completedDays,
          todayDay: todayDay,
        ),
        // 타임라인
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: 14,
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final mission = StudyPlanService.missions[index];
              final progress = progressMap[dayNumber];
              final isCompleted = progress?.completed ?? false;
              final isToday = dayNumber == todayDay;
              final isLocked = dayNumber > 3 && !isPremium;
              final isPast = dayNumber < todayDay;

              return _DayCard(
                mission: mission,
                progress: progress,
                isCompleted: isCompleted,
                isToday: isToday,
                isLocked: isLocked,
                isPast: isPast,
                isLast: index == 13,
                onTap: () => onDayTap(dayNumber),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Progress Header ────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int completedDays;
  final int todayDay;

  const _ProgressHeader({
    required this.completedDays,
    required this.todayDay,
  });

  @override
  Widget build(BuildContext context) {
    final progress = completedDays / 14;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppConfig.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day $todayDay / 14',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$completedDays일 완료',
                style: TextStyle(
                  color: AppConfig.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day Card ───────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final DailyMission mission;
  final DailyProgress? progress;
  final bool isCompleted;
  final bool isToday;
  final bool isLocked;
  final bool isPast;
  final bool isLast;
  final VoidCallback onTap;

  const _DayCard({
    required this.mission,
    required this.progress,
    required this.isCompleted,
    required this.isToday,
    required this.isLocked,
    required this.isPast,
    required this.isLast,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (mission.icon) {
      case 'code':
        return Icons.code;
      case 'storage':
        return Icons.storage;
      case 'edit_note':
        return Icons.edit_note;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'psychology':
        return Icons.psychology;
      case 'replay':
        return Icons.replay;
      case 'trending_up':
        return Icons.trending_up;
      case 'shuffle':
        return Icons.shuffle;
      case 'whatshot':
        return Icons.whatshot;
      case 'checklist':
        return Icons.checklist;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor;
    if (isCompleted) {
      accentColor = AppConfig.correctColor;
    } else if (isToday) {
      accentColor = AppConfig.primaryColor;
    } else if (isLocked) {
      accentColor = Colors.grey[700]!;
    } else {
      accentColor = Colors.grey[500]!;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 타임라인 라인
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppConfig.correctColor
                        : isToday
                            ? AppConfig.primaryColor
                            : AppConfig.cardColor,
                    border: Border.all(
                      color: accentColor,
                      width: isToday ? 2.5 : 1.5,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Center(
                          child: Text(
                            '${mission.dayNumber}',
                            style: TextStyle(
                              color: isToday
                                  ? Colors.white
                                  : Colors.grey[500],
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? AppConfig.correctColor.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 카드
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppConfig.primaryColor.withValues(alpha: 0.08)
                      : AppConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday
                        ? AppConfig.primaryColor.withValues(alpha: 0.4)
                        : isCompleted
                            ? AppConfig.correctColor.withValues(alpha: 0.3)
                            : AppConfig.borderColor,
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: isLocked
                          ? Icon(Icons.lock, color: Colors.grey[600], size: 20)
                          : Icon(_getIcon(), color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Day ${mission.dayNumber}',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppConfig.primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'TODAY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                              if (isLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mission.title,
                            style: TextStyle(
                              color: isLocked ? Colors.grey[600] : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLocked ? '프리미엄으로 잠금 해제' : mission.description,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                          if (isCompleted && progress != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppConfig.correctColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${progress!.questionsSolved}문제 | 정답률 ${progress!.accuracy.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: AppConfig.correctColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isCompleted
                          ? Icons.replay
                          : Icons.arrow_forward_ios,
                      color: accentColor.withValues(alpha: 0.6),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

