import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../config.dart';

class DdayTimer extends StatefulWidget {
  const DdayTimer({super.key});

  @override
  State<DdayTimer> createState() => _DdayTimerState();
}

class _DdayTimerState extends State<DdayTimer> {
  DateTime get _examDate => AppConfig.examDate;
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
    if (!mounted) return;
    final now = DateTime.now();

    // AppConfig.examDate 는 시험일 '자정'이다. 그대로 빼면 두 가지가 틀어진다.
    //  - 시험 전날 밤에도 남은 일수가 0으로 나와 D-Day 가 하루씩 적게 표시된다.
    //  - 시험 당일 새벽 0시부터 '시험 완료!'로 바뀐다. 정작 시험은 아직 안 봤는데.
    // 그래서 카운트다운 대상은 '시험일이 끝나는 시각'으로 잡는다.
    final endOfExamDay = DateTime(
      _examDate.year,
      _examDate.month,
      _examDate.day,
      23,
      59,
      59,
    );
    final diff = endOfExamDay.difference(now);

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

  /// 화면에 쓰는 D-N 값. 달력 기준 날짜 차이로 계산한다.
  /// Duration.inDays 는 남은 시간을 24로 나눈 값이라 전날 밤에 0이 되어버린다.
  int get _daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_examDate.year, _examDate.month, _examDate.day);
    final d = exam.difference(today).inDays;
    return d < 0 ? 0 : d;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _ddayLabel {
    if (_examPassed) return '시험 완료!';
    final days = _daysLeft;
    return days == 0 ? 'D-DAY' : 'D-$days';
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: redAccent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: redAccent.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 0,
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
              '${AppConfig.examRoundLabel} | ${AppConfig.examDate.month}월 ${AppConfig.examDate.day}일',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    ),
    ),
    );
  }
}
