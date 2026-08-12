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

  testWidgets('어떤 연도도 기출이라고 주장하지 않는다', (tester) async {
    await pump(tester);

    // 이 앱의 문항은 전부 AI 생성 예상문제다. 실제 실기는 회차당 20문항인데
    // 데이터는 회차당 40~60문항이라 기출 시험지일 수 없다.
    // '기출' 이 들어간 표기가 하나라도 살아나면 유저를 속이는 것이다.
    // "기출을 부정하는 고지" 는 기출이라는 단어를 쓸 수밖에 없으므로,
    // **기출이라고 주장하는 표기**만 잡는다.
    expect(find.textContaining('기출 기반'), findsNothing,
        reason: 'AI 생성 문항을 기출이라고 표시하면 안 된다');
    expect(find.text('기출'), findsNothing,
        reason: '기출 배지가 되살아나면 안 된다');

    // 2025년(과거)과 2026년(미래) 모두 같은 배지여야 한다.
    // 연도별로 배지가 다르면 "이 연도는 기출" 이라는 인상을 준다.
    expect(find.text('AI 예상'), findsNWidgets(2),
        reason: '2025·2026 두 연도 그룹 모두 같은 AI 예상 배지를 달아야 한다');
  });

  testWidgets('전부 AI 예상문제라는 고지가 목록 위에 보인다', (tester) async {
    await pump(tester);

    expect(find.textContaining('AI 가 만든 예상문제'), findsOneWidget,
        reason: '회차명이 "그 회차 시험지" 로 읽히지 않도록 고지가 필요하다');
    expect(find.textContaining('실제 기출 시험지가 아니'), findsOneWidget);
  });

  testWidgets('회차를 탭하면 그 (연도, 회차)를 그대로 DB에 요청한다', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.text('2025년 3회 유형'));
    await tester.pumpAndSettle();

    expect(db.requested, [(2025, 3)],
        reason: '인자가 (round, year) 로 뒤바뀌면 모든 회차가 빈 화면이 된다');
  });
}
