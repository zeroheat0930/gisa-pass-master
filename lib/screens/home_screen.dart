import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/study_stats.dart';
import '../providers/study_provider.dart';
import '../providers/stats_provider.dart';
import '../services/ai_exam_quota.dart';
import '../services/purchase_service.dart';
import '../widgets/dday_timer.dart';
import '../widgets/exam_quota_dialog.dart';
import '../widgets/pass_score_card.dart';
import 'quiz_screen.dart';
import 'ai_prediction_screen.dart';
import 'subscription_screen.dart';
import '../data/pass_rate_data.dart';
import '../services/database_service.dart';
import '../models/question.dart';
import 'round_list_screen.dart';
import 'pass_rate_screen.dart';
import 'stats_screen.dart';
import 'study_plan_screen.dart';

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  /// 복원 기출 회차 목록을 열려면 DB 가 필요하다.
  final DatabaseService db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isNavigating = false;
  late AnimationController _staggerController;

  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  static const int _elementCount = 7;

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

  void _startMode(BuildContext context, StudyMode mode, {String? subType}) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();

    try {
      final provider = context.read<StudyProvider>();
      if (mode == StudyMode.wrongAnswer) {
        await provider.loadWrongAnswerQuestions();
      } else if (mode == StudyMode.byType && subType != null) {
        await provider.loadQuestionsByType(subType);
      } else if (mode == StudyMode.bookmark) {
        await provider.loadBookmarkedQuestions();
      } else {
        await provider.loadQuestions();
      }

      if (!context.mounted) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => QuizScreen(mode: mode)),
      );

      // 풀이를 마치고 돌아왔으면 홈 통계를 다시 읽는다.
      // 탭 전환 시에만 갱신하면 이 주 경로(홈→퀴즈→뒤로→홈)가 통째로 빠져서,
      // 문제를 풀어도 홈 화면이 옛 값을 계속 보여준다.
      if (!context.mounted) return;
      await context.read<StatsProvider>().loadStats();
    } catch (_) {
      // 로딩 실패 시 조용히 복귀 (버튼은 다시 눌릴 수 있어야 한다)
    } finally {
      _isNavigating = false;
    }
  }

  void _startAiPrediction(BuildContext context) async {
    if (_isNavigating) return;
    // 가드는 **await 앞에서** 세워야 한다. 쿼터 조회를 기다리는 사이에 두 번째 탭이
    // 통과하면 모의고사 화면이 두 번 쌓이고 무료 응시도 2회 소모된다.
    _isNavigating = true;

    try {
      // 구독 화면은 AI 모의고사를 유료 전용으로 광고하는데 게이트가 없었다.
      // 완전히 막으면 쓰던 유저에게서 기능을 빼앗는 것이라 하루 1회는 열어둔다.
      final isPremium = context.read<PurchaseService>().isPremium;
      if (!await AiExamQuota.canStart(isPremium: isPremium)) {
        if (!context.mounted) return;
        final earned = await ExamQuotaDialog.show(
          context,
          isPremium: isPremium,
          onSeePremium: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const SubscriptionScreen()),
          ),
        );
        // 광고를 끝까지 봐서 1회를 얻었으면 그대로 이어서 응시한다.
        if (!earned || !context.mounted) return;
      }
      await _launchAiPrediction(context);
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _launchAiPrediction(BuildContext context) async {
    HapticFeedback.lightImpact();
    final provider = context.read<StudyProvider>();
    await provider.loadQuestions();
    // 쿼터는 여기서 깎지 않는다. 로딩 중에 뒤로가기로 빠져나가면 시험을 보지도
    // 않고 무료 1회가 증발한다. 소모는 시험이 실제로 시작되는 시점
    // (AiPredictionScreen 의 로딩 완료)에서 한다.
    if (!context.mounted) return;

    final questions = provider.questionList;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제가 없습니다.')),
      );
      return;
    }

    final examQuestions = questions.take(20).toList();
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => AiPredictionScreen(questions: examQuestions),
      ),
    );

    // 모의고사를 마치고 돌아왔으면 홈 통계를 다시 읽는다.
    if (!context.mounted) return;
    await context.read<StatsProvider>().loadStats();
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
              const SizedBox(height: 16),

              // 1.2 — 회차별 합격률 (D-Day 바로 아래)
              _staggered(
                1,
                _PassRateButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const PassRateScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 1.5 — 합격 예측 점수
              _staggered(
                2,
                PassScoreCard(
                  stats: stats,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (_) => const StatsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 2 — 학습 플랜 버튼
              _staggered(
                2,
                _StudyPlanButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => const StudyPlanScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // AI Prediction button
              _AiPredictionButton(
                onTap: () => _startAiPrediction(context),
              ),
              const SizedBox(height: 12),

              // 복원 기출 — AI 예상 바로 아래에 둔다. 시험이 가까울수록
              // 실제로 나온 문제를 풀고 싶어지는데, 그때마다 문제은행 탭을
              // 거쳐 들어가게 하면 손이 많이 간다.
              _RestoredExamButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => RoundListScreen(
                        db: widget.db,
                        sourceFilter: Question.sourceRestored,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 3 — Primary mode buttons
              _staggered(
                3,
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
                    const SizedBox(height: 12),
                    _ModeButton(
                      label: '즐겨찾기 복습',
                      icon: Icons.bookmark,
                      color: const Color(0xFFFFD700),
                      subtitle: '북마크한 중요 문제를 복습합니다',
                      onTap: () => _startMode(context, StudyMode.bookmark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4 — Type buttons
              _staggered(
                4,
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


              // 5 — Quick stats
              _staggered(5, _QuickStats(stats: stats)),
              const SizedBox(height: 20),

              // 6 — Dev message card
              _staggered(
                6,
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

// ─── 14일 합격 플랜 Button ──────────────────────────────────────────────────────

class _StudyPlanButton extends StatefulWidget {
  final VoidCallback onTap;

  const _StudyPlanButton({required this.onTap});

  @override
  State<_StudyPlanButton> createState() => _StudyPlanButtonState();
}

class _StudyPlanButtonState extends State<_StudyPlanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE53935),
                        Color(0xFFFF5722),
                        Color(0xFFFF7043),
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
                        color: const Color(0xFFE53935).withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
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
                            child: const Icon(Icons.calendar_month,
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
                                      '학습 플랜',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    _NewBadge(),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '당일치기부터 14일까지, 나만의 플랜 선택!',
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

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
      ),
      child: const Text(
        'NEW',
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

// ─── 회차별 합격률 ───────────────────────────────────────────────────────────

/// 합격률 화면으로 가는 입구. 최근 실기 합격률을 미리 보여줘서, 눌러볼 이유를
/// 버튼 자체가 들고 있게 한다.
class _PassRateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PassRateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latest = PassRateData.latest(ExamKind.practical);
    final average = PassRateData.roundAverage(ExamKind.practical);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppConfig.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConfig.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF569CD6).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF569CD6), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '회차별 합격률',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '실기 평균 ${average.toStringAsFixed(1)}% · '
                    '${latest.label} ${latest.rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Color(0xFF8A8A8A), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF6B6B6B), size: 20),
          ],
        ),
      ),
    );
  }
}

/// 복원 기출 회차 목록으로 가는 홈 버튼.
///
/// AI 예상문제와 시각적으로 구분되게 초록 계열을 쓴다 — 회차 목록의 '복원 기출'
/// 배지와 같은 색이라, 두 화면을 오갈 때 같은 것을 가리킨다는 게 드러난다.
class _RestoredExamButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RestoredExamButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppConfig.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppConfig.correctColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppConfig.correctColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.verified_outlined,
                  color: AppConfig.correctColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '복원 기출 풀기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '2020~2026년 21개 회차 · 420문항 전체 공개',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}
