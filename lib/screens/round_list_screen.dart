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
/// **기출과 예상문제를 반드시 구분해서 표시한다.** 아직 시행되지 않은 회차의
/// 문항을 기출로 보여주면 유저를 속이는 것이다.
class RoundListScreen extends StatefulWidget {
  final DatabaseService db;

  const RoundListScreen({super.key, required this.db});

  @override
  State<RoundListScreen> createState() => _RoundListScreenState();
}

class _RoundListScreenState extends State<RoundListScreen> {
  List<({int year, int round, int count})>? _rounds;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rounds = await widget.db.getRoundSummary();
      if (!mounted) return;
      setState(() => _rounds = rounds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _open(int year, int round) async {
    if (_opening) return;
    _opening = true;
    try {
      final questions = await widget.db.getQuestionsByRound(year, round);
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('해당 회차에 문제가 없습니다.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PastExamQuizScreen(
            questions: questions,
            title: '$year년 $round회',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('불러오지 못했습니다: $e')));
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
        title: const Text('회차별 문제집',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
          child: Text('불러오지 못했습니다.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
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
    final years = <int, List<({int year, int round, int count})>>{};
    for (final r in rounds) {
      years.putIfAbsent(r.year, () => []).add(r);
    }
    final sortedYears = years.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];
        final predicted = AppConfig.isPredictedYear(year);
        final items = years[year]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 10),
              child: Row(
                children: [
                  Text('$year년',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  _badge(predicted),
                ],
              ),
            ),
            ...items.map((r) => _roundTile(r, predicted)),
          ],
        );
      },
    );
  }

  Widget _badge(bool predicted) {
    final color = predicted ? AppConfig.warningColor : AppConfig.correctColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        predicted ? 'AI 예상' : '기출 기반',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _roundTile(({int year, int round, int count}) r, bool predicted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(r.year, r.round),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: Text('${r.round}회',
                        style: const TextStyle(
                            color: AppConfig.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.year}년 ${r.round}회',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        predicted
                            ? '${r.count}문항 · 시행 전 회차라 AI 예상문제입니다'
                            : '${r.count}문항',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
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

  const PastExamQuizScreen(
      {super.key, required this.questions, required this.title});

  @override
  Widget build(BuildContext context) =>
      buildPastExamQuiz(questions: questions, title: title);
}
