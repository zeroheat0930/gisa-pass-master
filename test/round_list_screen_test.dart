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
  final List<({int year, int round, String source, int count})> rounds;
  final List<(int, int, String?)> requested = [];

  _StubDb(this.rounds);

  @override
  Future<List<({int year, int round, String source, int count})>>
      getRoundSummary() async => rounds;

  @override
  Future<List<Question>> getQuestionsByRound(int year, int round,
      {String? source}) async {
    requested.add((year, round, source));
    // 빈 목록을 돌려 풀이 화면 push(광고·타이머 초기화)를 피한다 —
    // 여기서 검증하는 것은 인자 배선이다.
    return [];
  }
}

void main() {
  Future<_StubDb> pump(WidgetTester tester, {String? sourceFilter}) async {
    // 같은 2026년 2회 안에 복원 기출과 AI 예상이 함께 있는 상황을 재현한다.
    final db = _StubDb([
      (year: 2026, round: 2, source: 'restored', count: 12),
      (year: 2026, round: 2, source: 'ai', count: 41),
      (year: 2025, round: 3, source: 'ai', count: 56),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: RoundListScreen(db: db, sourceFilter: sourceFilter)));
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('AI 문항을 기출이라고 주장하지 않는다', (tester) async {
    await pump(tester);

    // AI 문항은 실제 실기(회차당 20문항)와 문항 수부터 맞지 않아 기출일 수 없다.
    // 'AI 예상' 묶음이 '기출' 로 표기되면 유저를 속이는 것이다.
    expect(find.textContaining('기출 기반'), findsNothing,
        reason: 'AI 생성 문항을 기출이라고 표시하면 안 된다');
    expect(find.text('2025년 3회 유형'), findsOneWidget,
        reason: 'AI 회차는 "유형" 으로 표기해야 한다');
    expect(find.text('2025년 3회'), findsNothing,
        reason: '회차명만 달면 그 회차 시험지로 읽힌다');
  });

  testWidgets('복원 기출과 AI 예상이 같은 회차 안에서 분리되어 보인다', (tester) async {
    await pump(tester);

    // 2026년 2회에 두 묶음이 각각 따로 떠야 한다. 합쳐지면 유저는 53문항 전부를
    // 기출로 오해하거나, 반대로 진짜 기출을 AI 문제로 오해한다.
    expect(find.text('2026년 2회 복원 기출'), findsOneWidget);
    expect(find.text('2026년 2회 유형'), findsOneWidget);
    expect(find.text('복원 기출'), findsOneWidget, reason: '복원 기출 배지');
    expect(find.text('AI 예상'), findsNWidgets(2), reason: 'AI 회차 2개의 배지');
    expect(find.textContaining('12문항 · 실제 시험 복원 · 전체 공개'), findsOneWidget);
  });

  testWidgets('출처와 라이선스가 목록 위에 표시된다', (tester) async {
    await pump(tester);

    // CC BY 4.0 제3조 (a)(1) 은 네 가지를 요구한다. 하나라도 빠지면
    // 라이선스가 소멸하고(제6조 (a)) 무단 이용이 된다. 넷 다 확인한다.
    expect(find.textContaining('Life-Journey'), findsOneWidget,
        reason: '1. 저작자 표시');
    expect(find.textContaining('CC BY 4.0'), findsOneWidget,
        reason: '2. 라이선스 종류 명시');
    expect(find.textContaining('creativecommons.org/licenses/by/4.0'),
        findsOneWidget,
        reason: '3. 라이선스 링크(URI) — 종류만 적고 링크를 빼면 안 된다');
    expect(find.textContaining('텍스트로 옮겼습니다'), findsOneWidget,
        reason: '4. 변경 공지 — 원문 이미지를 텍스트·JSON 으로 옮겼다');
    expect(find.textContaining('chobopark.tistory.com'), findsOneWidget,
        reason: '원문에 도달할 수 있어야 출처 표시가 실질적이다');
    expect(find.textContaining('유료 잠금 없이 전체 공개'), findsOneWidget);
    expect(find.textContaining('실제 기출 시험지가 아니'), findsOneWidget,
        reason: 'AI 문항에 대한 고지도 함께 있어야 한다');
  });

  testWidgets('회차를 탭하면 (연도, 회차, 출처)를 그대로 DB에 요청한다', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.text('2026년 2회 복원 기출'));
    await tester.pumpAndSettle();

    expect(db.requested, [(2026, 2, 'restored')],
        reason: '출처를 안 넘기면 복원 기출을 눌러도 AI 문항까지 섞여 나온다');
  });

  group('출처별로 갈라 보기', () {
    testWidgets('복원 기출만 고르면 AI 예상은 목록에 없다', (tester) async {
      await pump(tester, sourceFilter: Question.sourceRestored);

      expect(find.text('2026년 2회 복원 기출'), findsOneWidget);
      expect(find.text('2026년 2회 유형'), findsNothing);
      expect(find.text('2025년 3회 유형'), findsNothing);
    });

    testWidgets('AI 예상만 고르면 복원 기출은 목록에 없다', (tester) async {
      await pump(tester, sourceFilter: Question.sourceAi);

      expect(find.text('2026년 2회 유형'), findsOneWidget);
      expect(find.text('2026년 2회 복원 기출'), findsNothing);
    });

    testWidgets('AI 예상만 보는 화면에는 복원 기출 출처를 띄우지 않는다', (tester) async {
      // 이 화면에는 복원 기출이 한 문제도 없다. 여기에 "출처: Life-Journey" 를
      // 띄우면 AI 문항이 거기서 온 것처럼 읽혀 오히려 거짓말이 된다.
      await pump(tester, sourceFilter: Question.sourceAi);

      expect(find.textContaining('Life-Journey'), findsNothing);
      expect(find.textContaining('CC BY 4.0'), findsNothing);
      expect(find.textContaining('실제 기출 시험지가 아니'), findsOneWidget,
          reason: 'AI 고지는 남아야 한다');
    });

    testWidgets('복원 기출만 보는 화면에는 저작자 표시가 반드시 남는다', (tester) async {
      // 여기서 사라지면 라이선스가 소멸한다(제6조 (a)).
      await pump(tester, sourceFilter: Question.sourceRestored);

      expect(find.textContaining('Life-Journey'), findsOneWidget);
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);
      expect(find.textContaining('creativecommons.org/licenses/by/4.0'),
          findsOneWidget);
      expect(find.textContaining('텍스트로 옮겼습니다'), findsOneWidget);
      expect(find.textContaining('실제 기출 시험지가 아니'), findsNothing,
          reason: '실제 기출을 AI 가 만든 것처럼 읽히면 안 된다');
    });

    testWidgets('화면 제목이 무엇을 보고 있는지 말해준다', (tester) async {
      await pump(tester, sourceFilter: Question.sourceRestored);
      expect(find.text('복원 기출 회차별'), findsOneWidget);
    });
  });
}
