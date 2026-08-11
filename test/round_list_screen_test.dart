import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/screens/round_list_screen.dart';
import 'package:gisa_pass_master/services/database_service.dart';

// 회차별 문제집 배선 검증.
//
// 이 화면은 신설 이후 테스트가 0건이라, DB 조회 인자(year, round)를 뒤바꿔
// 화면 전체가 죽어도 전부 통과했다. 핵심 계약 두 가지를 검증한다:
//  1. 기출과 AI 예상 회차를 반드시 구분해 표시한다 (유료 유저 기만 방지)
//  2. 회차를 탭하면 정확히 그 (연도, 회차)를 DB에 요청한다

class _StubDb extends DatabaseService {
  final List<({int year, int round, int count})> rounds;
  final List<(int, int)> requested = [];

  _StubDb(this.rounds);

  @override
  Future<List<({int year, int round, int count})>> getRoundSummary() async =>
      rounds;

  @override
  Future<List<Question>> getQuestionsByRound(int year, int round) async {
    requested.add((year, round));
    // 빈 목록을 돌려 풀이 화면 push(광고·타이머 초기화)를 피한다 —
    // 여기서 검증하는 것은 인자 배선이다.
    return [];
  }
}

void main() {
  Future<_StubDb> pump(WidgetTester tester) async {
    final db = _StubDb([
      (year: 2026, round: 1, count: 122),
      (year: 2025, round: 3, count: 56),
      (year: 2025, round: 2, count: 60),
    ]);
    await tester.pumpWidget(MaterialApp(home: RoundListScreen(db: db)));
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('기출 연도와 AI 예상 연도를 구분해 표시한다', (tester) async {
    await pump(tester);

    // 2026 은 시행 전(lastRealExamYear=2025 초과)이므로 AI 예상이어야 한다.
    expect(find.text('AI 예상'), findsOneWidget,
        reason: '시행 전 회차를 기출로 표시하면 유저를 속이는 것이다');
    expect(find.text('기출 기반'), findsOneWidget,
        reason: '2025년 그룹은 기출 배지가 있어야 한다');
    expect(find.textContaining('AI 예상문제입니다'), findsOneWidget,
        reason: '예상 회차 타일에는 문항 수 옆에 안내 문구가 붙는다');
  });

  testWidgets('회차를 탭하면 그 (연도, 회차)를 그대로 DB에 요청한다', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.text('2025년 3회'));
    await tester.pumpAndSettle();

    expect(db.requested, [(2025, 3)],
        reason: '인자가 (round, year) 로 뒤바뀌면 모든 회차가 빈 화면이 된다');
  });
}
