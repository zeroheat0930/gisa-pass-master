import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/pass_rate_data.dart';

/// 회차별 합격률 화면.
///
/// 읽는 사람이 하려는 일은 두 가지다 — "이 시험이 얼마나 어렵나"(하나의 큰 수),
/// 그리고 "회차마다 얼마나 들쭉날쭉한가"(시간 순 흐름). 그래서 큰 숫자 하나 +
/// 회차별 막대 + 전체 표로 나눴다. 막대는 한 계열뿐이라 색으로 무엇을 구분할
/// 일이 없고, 따라서 범례도 없다(제목이 계열을 말해준다).
class PassRateScreen extends StatefulWidget {
  const PassRateScreen({super.key});

  @override
  State<PassRateScreen> createState() => _PassRateScreenState();
}

class _PassRateScreenState extends State<PassRateScreen> {
  // 이 앱은 실기 대비용이라 실기를 먼저 보여준다.
  ExamKind _kind = ExamKind.practical;

  @override
  Widget build(BuildContext context) {
    final rows = PassRateData.of(_kind);
    final average = PassRateData.roundAverage(_kind);

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        elevation: 0,
        title: const Text('회차별 합격률'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _KindToggle(
            value: _kind,
            onChanged: (k) {
              HapticFeedback.selectionClick();
              setState(() => _kind = k);
            },
          ),
          const SizedBox(height: 20),
          _HeadlineCard(kind: _kind),
          const SizedBox(height: 20),
          _ChartCard(kind: _kind, rows: rows, average: average),
          const SizedBox(height: 20),
          _TableCard(rows: rows, kind: _kind),
          const SizedBox(height: 16),
          const _FootNote(),
        ],
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  final ExamKind value;
  final ValueChanged<ExamKind> onChanged;

  const _KindToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 이 앱은 실기 대비용이라 실기를 왼쪽에 둔다.
          for (final kind in const [ExamKind.practical, ExamKind.written])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(kind),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kind == value
                        ? AppConfig.cardColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    kind.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kind == value
                          ? Colors.white
                          : const Color(0xFF8A8A8A),
                      fontSize: 14,
                      fontWeight: kind == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 큰 숫자 하나로 "얼마나 어려운 시험인가"에 답한다.
class _HeadlineCard extends StatelessWidget {
  final ExamKind kind;

  const _HeadlineCard({required this.kind});

  @override
  Widget build(BuildContext context) {
    final average = PassRateData.roundAverage(kind);
    final highest = PassRateData.highest(kind);
    final lowest = PassRateData.lowest(kind);
    final latest = PassRateData.latest(kind);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind.label} 회차 평균 합격률',
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '%',
                style: TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '2020년 개편 이후 ${PassRateData.of(kind).length}개 회차 기준',
            style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: '가장 높음',
                  value: '${highest.rate.toStringAsFixed(1)}%',
                  caption: highest.label,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: '가장 낮음',
                  value: '${lowest.rate.toStringAsFixed(1)}%',
                  caption: lowest.label,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: '최근',
                  value: '${latest.rate.toStringAsFixed(1)}%',
                  caption: latest.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          caption,
          style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
        ),
      ],
    );
  }
}

/// 회차별 막대. 계열이 하나뿐이라 색은 한 가지만 쓰고, 길이가 크기를 말한다.
/// 숫자는 모든 막대가 아니라 최고·최저·최신에만 붙인다.
class _ChartCard extends StatelessWidget {
  final ExamKind kind;
  final List<PassRateEntry> rows;
  final double average;

  const _ChartCard({
    required this.kind,
    required this.rows,
    required this.average,
  });

  static const _barColor = Color(0xFF569CD6);
  static const double _plotHeight = 160;

  /// 막대 폭은 회차 수에 맞춰 나눈다. 예전엔 고정 폭 + 가로 스크롤이었는데,
  /// 21개 회차 중 11개만 보이고 나머지는 스크롤 뒤에 숨었다. 이 차트의 목적이
  /// "회차마다 얼마나 들쭉날쭉한가"를 한눈에 보는 것이라 숨으면 의미가 없다.
  static const double _barGapRatio = 0.34;

  @override
  Widget build(BuildContext context) {
    // y축 최대치는 데이터 최댓값 위로 여유를 둬 라벨이 천장에 붙지 않게 한다.
    final maxRate = rows.fold(0.0, (m, e) => e.rate > m ? e.rate : m);
    final top = ((maxRate / 20).ceil() + 1) * 20.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '회차별 합격률',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '점선은 평균 ${average.toStringAsFixed(1)}%',
            style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final slot = constraints.maxWidth / rows.length;
              return _Plot(
                kind: kind,
                rows: rows,
                top: top,
                average: average,
                barColor: _barColor,
                plotHeight: _plotHeight,
                slotWidth: slot,
                barWidth: slot * (1 - _barGapRatio),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Plot extends StatelessWidget {
  final ExamKind kind;
  final List<PassRateEntry> rows;
  final double top;
  final double average;
  final Color barColor;
  final double plotHeight;
  final double slotWidth;
  final double barWidth;

  const _Plot({
    required this.kind,
    required this.rows,
    required this.top,
    required this.average,
    required this.barColor,
    required this.plotHeight,
    required this.slotWidth,
    required this.barWidth,
  });

  @override
  Widget build(BuildContext context) {
    final labelled = {
      PassRateData.highest(kind),
      PassRateData.lowest(kind),
      PassRateData.latest(kind),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: plotHeight,
          child: Stack(
            children: [
              // 평균선 — 눈에 띄되 막대를 이기지 않는 정도로만.
              Positioned(
                left: 0,
                right: 0,
                bottom: plotHeight * (average / top),
                child: const _DashedLine(),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final e in rows)
                    SizedBox(
                      width: slotWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (labelled.contains(e))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                e.rate.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Color(0xFFBDBDBD),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Container(
                            width: barWidth,
                            height: (plotHeight - 18) * (e.rate / top),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // x축 — 연도가 바뀌는 자리에만 연도를 쓴다. 매 막대에 다 쓰면 뭉갠다.
        Row(
          children: [
            for (var i = 0; i < rows.length; i++)
              SizedBox(
                width: slotWidth,
                child: Text(
                  i == 0 || rows[i].year != rows[i - 1].year
                      ? "'${rows[i].year % 100}"
                      : '',
                  textAlign: TextAlign.center,
                  // 칸 폭(가로를 회차 수로 나눈 값)보다 "'20" 이 넓어서 그냥 두면
                  // 두 줄로 접힌다. 라벨이 붙는 칸의 좌우는 비어 있으므로
                  // 접지 말고 넘치게 둔다.
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 4.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: const Color(0xFF6B6B6B),
            ),
          ),
        );
      },
    );
  }
}

/// 표 — 회차가 20개를 넘어 차트만으로는 개별 값을 읽을 수 없다.
/// 접근성 측면에서도 색·길이 말고 숫자로 읽을 경로가 하나 있어야 한다.
class _TableCard extends StatelessWidget {
  final List<PassRateEntry> rows;
  final ExamKind kind;

  const _TableCard({required this.rows, required this.kind});

  String _comma(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      color: Color(0xFF8A8A8A),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    const cell = TextStyle(color: Color(0xFFE0E0E0), fontSize: 12);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${kind.label} 전체 회차',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.4),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.8),
              3: FlexColumnWidth(1.6),
            },
            border: TableBorder(
              horizontalInside: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            children: [
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('회차', style: header),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '응시',
                      textAlign: TextAlign.right,
                      style: header,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '합격',
                      textAlign: TextAlign.right,
                      style: header,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '합격률',
                      textAlign: TextAlign.right,
                      style: header,
                    ),
                  ),
                ],
              ),
              for (final e in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(e.label, style: cell),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _comma(e.taken),
                        textAlign: TextAlign.right,
                        style: cell,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _comma(e.passed),
                        textAlign: TextAlign.right,
                        style: cell,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${e.rate.toStringAsFixed(2)}%',
                        textAlign: TextAlign.right,
                        style: cell.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '누적 ${_comma(rows.fold(0, (s, e) => s + e.passed))}명 합격 / '
            '${_comma(rows.fold(0, (s, e) => s + e.taken))}명 응시 '
            '(${PassRateData.cumulativeRate(kind).toStringAsFixed(2)}%)',
            style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  const _FootNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '2020년 NCS 개편 이후 공개된 국가기술자격 통계 기준입니다. '
      '2020년은 일정 순연으로 필기가 1·2회 통합, 실기가 5회까지 시행되었습니다.',
      style: TextStyle(color: Color(0xFF5A5A5A), fontSize: 11, height: 1.5),
    );
  }
}
