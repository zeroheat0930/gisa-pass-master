import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';

class DdayTimer extends StatefulWidget {
  const DdayTimer({super.key});

  @override
  State<DdayTimer> createState() => _DdayTimerState();
}

class _DdayTimerState extends State<DdayTimer> {
  static final DateTime _examDate = AppConfig.examDate;
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _examPassed = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = _examDate.difference(now);
    setState(() {
      if (diff.isNegative) {
        _examPassed = true;
        _remaining = Duration.zero;
      } else {
        _examPassed = false;
        _remaining = diff;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _ddayLabel {
    if (_examPassed) return '시험 완료!';
    final days = _remaining.inDays;
    return 'D-$days';
  }

  String get _timeLabel {
    if (_examPassed) return '';
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const redAccent = AppConfig.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: redAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: redAccent.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppConfig.examLabel,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ddayLabel,
            style: const TextStyle(
              color: redAccent,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          if (!_examPassed) ...[
            const SizedBox(height: 4),
            Text(
              _timeLabel,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontFamily: 'monospace',
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${AppConfig.examDate.year}년 ${AppConfig.examDate.month}월 ${AppConfig.examDate.day}일',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
