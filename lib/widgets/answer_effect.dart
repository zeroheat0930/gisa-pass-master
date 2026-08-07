import 'package:flutter/material.dart';
import '../config.dart';

class AnswerEffect extends StatefulWidget {
  final bool isCorrect;
  final VoidCallback? onComplete;

  const AnswerEffect({
    super.key,
    required this.isCorrect,
    this.onComplete,
  });

  @override
  State<AnswerEffect> createState() => _AnswerEffectState();
}

class _AnswerEffectState extends State<AnswerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 60,
      ),
    ]).animate(_controller);

    // Shake animation for wrong answers
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0.05, 0)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
            begin: const Offset(0.05, 0), end: const Offset(-0.05, 0)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
            begin: const Offset(-0.05, 0), end: const Offset(0.05, 0)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0.05, 0), end: Offset.zero),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(Offset.zero),
        weight: 60,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isCorrect ? AppConfig.correctColor : AppConfig.wrongColor;
    final icon = widget.isCorrect ? Icons.check_circle : Icons.cancel;
    final label = widget.isCorrect ? '정답!' : '오답!';

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 72),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );

    if (!widget.isCorrect) {
      content = SlideTransition(
        position: _shakeAnimation,
        child: content,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: content,
    );
  }
}

/// Overlay helper to show AnswerEffect over the current screen.
class AnswerEffectOverlay {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context, {
    required bool isCorrect,
    VoidCallback? onComplete,
  }) {
    _entry?.remove();
    _entry = OverlayEntry(
      // Positioned 는 ParentDataWidget 이라 Overlay 의 Stack 직계 자식이어야 한다.
      // IgnorePointer 로 바깥을 감싸면 "Incorrect use of ParentDataWidget" 예외가 나서
      // 답을 제출할 때마다 학습 화면이 깨진다. 반드시 Positioned 가 바깥이어야 한다.
      //
      // IgnorePointer 자체는 필요하다. 없으면 애니메이션이 끝날 때까지(최대 1.2초)
      // 화면 전체의 터치를 먹어 유저가 '다음'을 눌러도 반응하지 않는다.
      builder: (ctx) => Positioned.fill(
        child: IgnorePointer(
          child: Material(
            color: Colors.black45,
            child: Center(
              child: AnswerEffect(
                isCorrect: isCorrect,
                onComplete: () {
                  dismiss();
                  onComplete?.call();
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  /// 표시 중인 오버레이를 즉시 제거한다.
  ///
  /// 이 오버레이는 라우트가 아니라 Navigator 의 Overlay 에 붙는다. 그래서 효과가
  /// 끝나기 전에 화면을 벗어나면 이전 화면 위에 그대로 남는다.
  /// 퀴즈 화면의 dispose 에서 반드시 호출할 것.
  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}
