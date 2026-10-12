import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../config.dart';

/// D-Day 카드에 보일 내용 한 벌. 상태 판정은 [DdayStatus.at] 한 곳에서 끝낸다.
@immutable
class DdayStatus {
  /// 큰 글씨 (D-12 / D-DAY / 시험 진행 중 / 수고하셨습니다!)
  final String headline;

  /// 시:분:초 카운트다운. 카운트다운 중이 아니면 null.
  final String? clock;

  /// 아래 작은 안내 줄.
  final String caption;

  const DdayStatus({
    required this.headline,
    required this.clock,
    required this.caption,
  });

  /// [now] 시점의 D-Day 카드 상태.
  ///
  /// 예전에는 '시험일 23:59:59' 를 겨냥해서 10/24 10:00 에 'D-1 13:59:59' 가
  /// 뜨고(실제 시작까지는 23시간 30분), 시험이 끝난 오후에도 시간이 흘렀다.
  /// 또 '시험 완료!' 분기는 자정에 nextExam 이 먼저 다음 회차로 넘어가서
  /// 한 번도 보인 적이 없는 죽은 코드였다. 이제 기준은 **시험 시작 시각**이고,
  ///  1) 시험 다음날부터 며칠간: 수고 인사 + 다음 시험 안내 (nextExam 보다 먼저 본다)
  ///  2) 시작 전: D-N(당일은 D-DAY) + 시작까지 남은 시:분:초
  ///  3) 시작~종료: 시험 진행 중
  ///  4) 종료~자정: 수고하셨습니다!
  ///
  /// 'D-N' 숫자는 AppConfig.daysUntilExam 정본을 쓴다(달력 기준). [now] 는
  /// 반드시 AppConfig.now 여야 두 값이 같은 시계를 본다.
  static DdayStatus at(DateTime now) {
    final finished = AppConfig.recentlyFinishedExam;
    if (finished != null) {
      return DdayStatus(
        headline: '수고하셨습니다!',
        clock: null,
        caption: '다음 시험 ${AppConfig.examRoundLabel}'
            '${AppConfig.isExamDateConfirmed ? '' : ' (예정)'}',
      );
    }

    final exam = AppConfig.examDate;
    final start = AppConfig.examStartOn(exam);
    final end = AppConfig.examEndOn(exam);
    final dateCaption =
        '${AppConfig.examRoundLabel} | ${exam.month}월 ${exam.day}일'
        // 확정 공고가 아니라 통상 시기로 추정한 날짜면 '예정'을 붙인다.
        // 추정치를 확정 일정과 같은 형식으로 보여주면 유저를 오도한다.
        '${AppConfig.isExamDateConfirmed ? '' : ' (예정)'}';

    if (now.isBefore(start)) {
      final days = AppConfig.daysUntilExam;
      return DdayStatus(
        headline: days == 0 ? 'D-DAY' : 'D-$days',
        clock: _formatClock(start.difference(now)),
        caption: dateCaption,
      );
    }
    if (now.isBefore(end)) {
      return DdayStatus(
        headline: '시험 진행 중',
        clock: null,
        caption: '${AppConfig.examRoundLabel} | 끝까지 침착하게!',
      );
    }
    return DdayStatus(
      headline: '수고하셨습니다!',
      clock: null,
      caption: '${AppConfig.examRoundLabel} 시험을 마쳤어요',
    );
  }

  /// 남은 시간의 '하루 미만' 부분만 시:분:초로. 일 단위는 D-N 이 맡는다.
  static String _formatClock(Duration remaining) {
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

class DdayTimer extends StatefulWidget {
  const DdayTimer({super.key});

  @override
  State<DdayTimer> createState() => _DdayTimerState();
}

class _DdayTimerState extends State<DdayTimer> {
  late Timer _timer;
  late DdayStatus _status;

  @override
  void initState() {
    super.initState();
    _status = DdayStatus.at(AppConfig.now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _status = DdayStatus.at(AppConfig.now));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
          // '수고하셨습니다!' 같은 긴 문구가 56pt 로 넘치지 않게 줄여서 맞춘다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _status.headline,
              style: const TextStyle(
                color: redAccent,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          if (_status.clock != null) ...[
            const SizedBox(height: 4),
            Text(
              _status.clock!,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontFamily: 'monospace',
                letterSpacing: 3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _status.caption,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }
}
