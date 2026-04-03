import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/study_stats.dart';
import '../providers/study_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/dday_timer.dart';
import 'quiz_screen.dart';
import 'ai_prediction_screen.dart';
import 'subscription_screen.dart';

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isNavigating = false;
  late AnimationController _staggerController;

  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  static const int _elementCount = 8;

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnims = List.generate(_elementCount, (i) {
      final start = i * 0.10;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = List.generate(_elementCount, (i) {
      final start = i * 0.10;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadStats();
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  void _startMode(BuildContext context, StudyMode mode, {String? subType}) {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppConfig.primaryColor),
      ),
    );
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
      _isNavigating = false;
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading dialog
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => QuizScreen(mode: mode),
        ),
      );
    }).catchError((_) {
      _isNavigating = false;
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _startAiPrediction(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppConfig.primaryColor),
      ),
    );
    final provider = context.read<StudyProvider>();
    try {
      await provider.loadQuestions();
    } finally {
      _isNavigating = false;
      if (context.mounted) Navigator.pop(context); // dismiss loading dialog
    }
    if (!context.mounted) return;

    final questions = provider.questionList;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제가 없습니다.')),
      );
      return;
    }

    final examQuestions = questions.take(20).toList();
    Navigator.push(
      context,
      CupertinoPageRoute(
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
              // 0 — Header
              _staggered(0, _Header(onProTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                      builder: (_) => const SubscriptionScreen()),
                );
              })),
              const SizedBox(height: 20),

              // 1 — D-Day timer with Hero
              _staggered(
                1,
                Hero(
                  tag: 'dday_timer',
                  child: Material(
                    type: MaterialType.transparency,
                    child: const DdayTimer(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2 — Daily Challenge card
              _staggered(
                2,
                _DailyChallengeCard(stats: stats),
              ),
              const SizedBox(height: 16),

              // 3 — AI Prediction button
              _staggered(
                3,
                _AiPredictionButton(
                  onTap: () => _startAiPrediction(context),
                ),
              ),
              const SizedBox(height: 12),

              // 4 — Primary mode buttons
              _staggered(
                4,
                Column(
                  children: [
                    _ModeButton(
                      label: '예측 학습 시작',
                      icon: Icons.auto_awesome,
                      color: AppConfig.primaryColor,
                      subtitle: 'AI가 자주 나오는 문제를 선별합니다',
                      onTap: () => _startMode(context, StudyMode.prediction),
                    ),
                    const SizedBox(height: 12),
                    _ModeButton(
                      label: '스파르타 오답노트',
                      icon: Icons.local_fire_department,
                      color: AppConfig.warningColor,
                      subtitle: '틀린 문제를 반복 학습합니다',
                      onTap: () => _startMode(context, StudyMode.wrongAnswer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5 — Type buttons
              _staggered(
                5,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '유형별 학습',
                      style: TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6 — Quick stats
              _staggered(6, _QuickStats(stats: stats)),
              const SizedBox(height: 20),

              // 7 — Dev message card
              _staggered(
                7,
                _DevMessageCard(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const SubscriptionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Daily Challenge Card ─────────────────────────────────────────────────────

class _DailyChallengeCard extends StatelessWidget {
  final StudyStats stats;

  const _DailyChallengeCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final solved = stats.todaySolved;
    final mission1Done = solved >= 10;
    // missions 2 & 3 are display-only (not yet tracked)
    final mission2Done = stats.todaySolved < 0; // always false placeholder
    final mission3Done = stats.todaySolved < 0; // always false placeholder

    final completedCount =
        (mission1Done ? 1 : 0) + (mission2Done ? 1 : 0) + (mission3Done ? 1 : 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.07),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '오늘의 도전',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$completedCount/3 완료',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mission 1 — 10문제 풀기 (progress bar)
              _MissionProgressRow(
                label: '10문제 풀기',
                current: solved.clamp(0, 10),
                total: 10,
                done: mission1Done,
              ),
              const SizedBox(height: 10),

              // Mission 2 — 3연속 정답
              _MissionCheckRow(
                label: '3연속 정답 달성',
                done: mission2Done,
              ),
              const SizedBox(height: 10),

              // Mission 3 — 오답노트 복습
              _MissionCheckRow(
                label: '오답노트 복습하기',
                done: mission3Done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionProgressRow extends StatelessWidget {
  final String label;
  final int current;
  final int total;
  final bool done;

  const _MissionProgressRow({
    required this.label,
    required this.current,
    required this.total,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? current / total : 0.0;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done
                ? AppConfig.correctColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: done
                  ? AppConfig.correctColor
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: done
              ? const Icon(Icons.check, color: AppConfig.correctColor, size: 13)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: done ? AppConfig.correctColor : Colors.grey[300],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  Text(
                    '$current/$total',
                    style: TextStyle(
                      color: done ? AppConfig.correctColor : Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.toDouble(),
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    done ? AppConfig.correctColor : const Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionCheckRow extends StatelessWidget {
  final String label;
  final bool done;

  const _MissionCheckRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done
                ? AppConfig.correctColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(
              color: done
                  ? AppConfig.correctColor
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: done
              ? const Icon(Icons.check, color: AppConfig.correctColor, size: 13)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: done ? AppConfig.correctColor : Colors.grey[300],
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onProTap;

  const _Header({required this.onProTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Text(
          '기사패스마스터',
          style: TextStyle(
            color: AppConfig.primaryColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        _ProBadge(onTap: onProTap),
      ],
    );
  }
}

// ─── PRO Badge with shimmer ───────────────────────────────────────────────────

class _ProBadge extends StatefulWidget {
  final VoidCallback onTap;

  const _ProBadge({required this.onTap});

  @override
  State<_ProBadge> createState() => _ProBadgeState();
}

class _ProBadgeState extends State<_ProBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFFFFD700),
                  Color(0xFFFFF5CC),
                  Color(0xFFFFA000),
                ],
                stops: [
                  (_shimmerAnim.value - 0.4).clamp(0.0, 1.0),
                  _shimmerAnim.value.clamp(0.0, 1.0),
                  (_shimmerAnim.value + 0.4).clamp(0.0, 1.0),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── AI Prediction Button ─────────────────────────────────────────────────────

class _AiPredictionButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AiPredictionButton({required this.onTap});

  @override
  State<_AiPredictionButton> createState() => _AiPredictionButtonState();
}

class _AiPredictionButtonState extends State<_AiPredictionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedBuilder(
              animation: _shimmerAnim,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6A1B9A),
                        Color(0xFF8E24AA),
                        Color(0xFF9C27B0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6A1B9A).withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Shimmer overlay
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.07),
                                  Colors.transparent,
                                ],
                                stops: [
                                  (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                                  _shimmerAnim.value.clamp(0.0, 1.0),
                                  (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(Icons.psychology,
                                color: Colors.white, size: 28),
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
                                        letterSpacing: 0.3,
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
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white60, size: 16),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
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
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3), width: 0.5),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Mode Button ──────────────────────────────────────────────────────────────

class _ModeButton extends StatefulWidget {
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
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: widget.color.withValues(alpha: 0.7), size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Type Button ──────────────────────────────────────────────────────────────

class _TypeButton extends StatefulWidget {
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
  State<_TypeButton> createState() => _TypeButtonState();
}

class _TypeButtonState extends State<_TypeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(widget.icon, size: 22, color: widget.color),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Stats ──────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  final StudyStats stats;

  const _QuickStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final todaySolved = stats.todaySolved;
    final todayAccuracy = stats.todayAccuracy;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppConfig.correctColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppConfig.correctColor.withValues(alpha: 0.06),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
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
                color: Colors.white.withValues(alpha: 0.08),
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
        ),
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
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Dev Message Card ─────────────────────────────────────────────────────────

class _DevMessageCard extends StatefulWidget {
  final VoidCallback onTap;

  const _DevMessageCard({required this.onTap});

  @override
  State<_DevMessageCard> createState() => _DevMessageCardState();
}

class _DevMessageCardState extends State<_DevMessageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1520).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF1E3050),
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
                        border: Border.all(
                          color:
                              const Color(0xFF2196F3).withValues(alpha: 0.25),
                          width: 1,
                        ),
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
                          letterSpacing: 0.2,
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
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    final glowOpacity = 0.15 + (_pulseAnim.value * 0.25);
                    final borderOpacity = 0.25 + (_pulseAnim.value * 0.35);
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2196F3)
                              .withValues(alpha: borderOpacity),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3)
                                .withValues(alpha: glowOpacity),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Text(
                        '광고 제거하고 공부에 집중하기 →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
