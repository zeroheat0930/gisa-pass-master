import 'package:flutter/material.dart';

import '../config.dart';
import '../models/question.dart';
import '../services/database_service.dart';
import 'past_exam_screen.dart';

/// 회차별 문제집.
///
/// 수험생이 가장 원하는 접근 방식이다. "2025년 3회만 풀어보고 싶다" 는 요구가
/// 유형별 필터로는 충족되지 않는다.
///
/// **이 앱의 문항은 전부 AI 가 만든 예상문제다. 기출 시험지가 아니다.**
/// 연도·회차는 "그 회차를 본떴다" 는 뜻이지 "그 회차에 나온 문제" 가 아니다.
/// (실제 정보처리기사 실기는 회차당 20문항인데 이 데이터는 회차당 40~60문항이다)
/// 한때 2025년 이하를 '기출 기반' 으로 표시했으나 사실과 달라 걷어냈다.
/// **어떤 화면에서도 기출이라고 주장하지 말 것.**
class RoundListScreen extends StatefulWidget {
  final DatabaseService db;

  /// 이 출처만 보여준다. null 이면 전부.
  ///
  /// 복원 기출과 AI 예상은 성격이 완전히 다른 자료라, 한 목록에 섞어두면
  /// "오늘은 기출만 풀자" 같은 아주 흔한 의도를 화면이 받아주지 못한다.
  /// 그래서 문제은행에서 각각 별도 입구로 들어온다.
  final String? sourceFilter;

  const RoundListScreen({super.key, required this.db, this.sourceFilter});

  String get title => switch (sourceFilter) {
    Question.sourceRestored => '복원 기출 회차별',
    Question.sourceAi => 'AI 예상 회차별',
    _ => '회차별 문제집',
  };

  @override
  State<RoundListScreen> createState() => _RoundListScreenState();
}

class _RoundListScreenState extends State<RoundListScreen> {
  List<({int year, int round, String source, int count})>? _rounds;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.db.getRoundSummary();
      final rounds = widget.sourceFilter == null
          ? all
          : all.where((r) => r.source == widget.sourceFilter).toList();
      if (!mounted) return;
      setState(() => _rounds = rounds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _open(int year, int round, String source) async {
    if (_opening) return;
    _opening = true;
    try {
      final questions = await widget.db.getQuestionsByRound(
        year,
        round,
        source: source,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('해당 회차에 문제가 없습니다.')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PastExamQuizScreen(
            questions: questions,
            title: source == Question.sourceRestored
                ? '$year년 $round회 복원 기출'
                : '$year년 $round회 유형',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('불러오지 못했습니다: $e')));
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '불러오지 못했습니다.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final rounds = _rounds;
    if (rounds == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppConfig.primaryColor),
      );
    }
    if (rounds.isEmpty) {
      return const Center(
        child: Text('문제가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    // 연도별로 묶어서 보여준다
    final years =
        <int, List<({int year, int round, String source, int count})>>{};
    for (final r in rounds) {
      years.putIfAbsent(r.year, () => []).add(r);
    }
    final sortedYears = years.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: sortedYears.length + 1,
      itemBuilder: (context, index) {
        // 첫 항목은 출처 고지. 목록 위에 항상 보이게 둔다.
        if (index == 0) {
          return _notice(
            rounds.any((r) => r.source == Question.sourceRestored),
            rounds.any((r) => r.source != Question.sourceRestored),
          );
        }

        final year = sortedYears[index - 1];
        final items = years[year]!;

        // 연도별 배지는 달지 않는다. 한 연도 안에 복원 기출과 AI 예상이
        // 함께 있을 수 있어서, 배지는 회차 타일마다 붙인다.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 10),
              child: Text(
                '$year년',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ...items.map(_roundTile),
          ],
        );
      },
    );
  }

  /// 출처 배지. 복원 기출과 AI 예상문제는 성격이 완전히 다르므로 색까지 나눈다.
  Widget _badge(String source) {
    final restored = source == Question.sourceRestored;
    final color = restored ? AppConfig.correctColor : AppConfig.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        restored ? '복원 기출' : 'AI 예상',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 화면 맨 위 고지 + 출처 표기.
  ///
  /// 회차명이 "그 회차 시험지" 로 읽히지 않게 못박고, 복원 기출의 출처를 밝힌다.
  /// **CC BY 4.0 의 유일한 의무가 저작자 표시이므로 이 안내는 지우면 안 된다.**
  ///
  /// 다만 **목록에 실제로 있는 것만 고지한다.** AI 예상만 있는 화면에
  /// "출처: Life-Journey 블로그" 를 띄우면 AI 문항이 거기서 온 것처럼 읽혀
  /// 오히려 거짓말이 된다. 반대로 복원 기출만 있는 화면에 AI 고지를 띄우면
  /// 실제 기출을 AI 가 만든 것처럼 읽힌다.
  Widget _notice(bool hasRestored, bool hasAi) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasRestored)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: AppConfig.correctColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '복원 기출 — 실제 시험을 응시자들이 복원한 문제입니다.\n'
                    '유료 잠금 없이 전체 공개합니다.\n'
                    '출처: Life-Journey 블로그 (CC BY 4.0)',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          if (hasRestored && hasAi) const SizedBox(height: 10),
          if (hasAi)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppConfig.warningColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 예상 — 기출 유형을 학습한 AI 가 만든 문제입니다.\n'
                    '실제 기출 시험지가 아니며, 연도·회차는 출제 경향의 기준입니다.',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _roundTile(({int year, int round, String source, int count}) r) {
    final restored = r.source == Question.sourceRestored;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(r.year, r.round, r.source),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${r.round}회',
                      style: const TextStyle(
                        color: AppConfig.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI 문항은 "2023년 2회" 가 아니라 "2023년 2회 유형" 이다.
                      // 회차명만 달면 그 회차 시험지로 읽힌다.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              restored
                                  ? '${r.year}년 ${r.round}회 복원 기출'
                                  : '${r.year}년 ${r.round}회 유형',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _badge(r.source),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        restored
                            ? '${r.count}문항 · 실제 시험 복원 · 전체 공개'
                            : '${r.count}문항 · AI 예상문제',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 회차별 문제집에서 쓰는 풀이 화면.
/// 문제은행의 풀이 화면과 동일한 구현을 재사용한다(복붙하지 않는다).
class PastExamQuizScreen extends StatelessWidget {
  final List<Question> questions;
  final String title;

  const PastExamQuizScreen({
    super.key,
    required this.questions,
    required this.title,
  });

  @override
  Widget build(BuildContext context) =>
      buildPastExamQuiz(questions: questions, title: title);
}
