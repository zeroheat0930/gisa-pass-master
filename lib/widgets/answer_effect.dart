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
      builder: (ctx) => Positioned.fill(
        child: Material(
          color: Colors.black45,
          child: Center(
            child: AnswerEffect(
              isCorrect: isCorrect,
              onComplete: () {
                _entry?.remove();
                _entry = null;
                onComplete?.call();
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }
}
