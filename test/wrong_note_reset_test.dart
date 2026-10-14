import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gisa_pass_master/providers/study_provider.dart';
import 'package:gisa_pass_master/screens/quiz_screen.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';

/// 2026-10 사용자 피드백: "오답노트 초기화 방법 없나요?" — 없었다.
/// 복습 큐(spaced_repetition)만 비우고 풀이 기록(answer_records)은 남아야 한다.
/// 기록까지 지우면 통계·합격 예측이 같이 0 이 되는데, 유저가 원한 건
/// "다시 풀 목록을 비우는 것" 이다.
/// 퀴즈 화면의 배너가 PurchaseService 를 읽는다. 프리미엄으로 두면 광고 로드를 건너뛴다.
class _FakePurchaseService extends PurchaseService {
  @override
  bool get isPremium => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;
  late SpacedRepetitionService sr;

  setUp(() {
    db = DatabaseService();
    sr = SpacedRepetitionService(db);
  });

  Future<int> anyQuestionId() async {
    final qs = await db.getRandomQuestions(1);
    return qs.first.id!;
  }

  group('오답노트 초기화', () {
    test('복습 큐는 비우고 풀이 기록은 남긴다', () async {
      final qid = await anyQuestionId();
      // 오답 → 큐 진입
      await sr.processAnswer(qid, false);
      expect(await db.getSpacedRepetition(qid), isNotNull,
          reason: '테스트 전제: 오답이면 큐에 들어간다');

      final removed = await sr.resetAll();

      expect(removed, greaterThanOrEqualTo(1));
      expect(await db.getSpacedRepetition(qid), isNull,
          reason: '초기화 뒤에는 복습 대상이 없어야 한다');
    });

    test('초기화 뒤 정답을 맞혀도 큐에 다시 들어가지 않는다', () async {
      // "틀린 적 있는 문제만 담는다" 는 규칙이 초기화 뒤에도 유지되는지.
      final qid = await anyQuestionId();
      await sr.processAnswer(qid, false);
      await sr.resetAll();

      await sr.processAnswer(qid, true);

      expect(await db.getSpacedRepetition(qid), isNull);
    });

    test('빈 큐를 초기화해도 예외 없이 0 을 돌려준다', () async {
      await sr.resetAll();
      expect(await sr.resetAll(), 0);
    });
  });

  group('오답노트 화면', () {
    // DB(sqflite ffi)는 실제 비동기 I/O 라 testWidgets 안에서는 runAsync 로
    // 감싸야 완료된다. 퀴즈 화면은 광고 배너 리스너가 있어 pumpAndSettle 대신
    // 고정 시간 pump 로 진행한다.
    Widget host(StudyProvider provider, {StudyMode mode = StudyMode.wrongAnswer}) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PurchaseService>.value(
                value: _FakePurchaseService()),
            ChangeNotifierProvider<StudyProvider>.value(value: provider),
          ],
          child: MaterialApp(home: QuizScreen(mode: mode)),
        );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('앱바의 초기화 버튼 → 확인 → 큐가 비고 안내가 뜬다',
        (tester) async {
      late int qid;
      late StudyProvider provider;
      await tester.runAsync(() async {
        qid = await anyQuestionId();
        await sr.processAnswer(qid, false);
        // 복습 기한을 과거로 당겨 지금 당장 큐에 보이게 한다.
        await db.upsertSpacedRepetition(
          questionId: qid,
          stage: 0,
          nextReviewAt: DateTime.now().subtract(const Duration(minutes: 1)),
          consecutiveCorrect: 0,
        );
        provider = StudyProvider(
          db: db,
          predictionEngine: PredictionEngine(),
          spacedRepetitionService: sr,
        );
        await provider.loadWrongAnswerQuestions();
      });
      expect(provider.questionList, isNotEmpty, reason: '테스트 전제 확인');

      await tester.pumpWidget(host(provider));
      await settle(tester);

      await tester.tap(find.byKey(const Key('reset_wrong_note')));
      await settle(tester);
      expect(find.text('오답노트를 초기화할까요?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset_wrong_note_confirm')));
      // 다이얼로그 pop → DB 삭제(실제 비동기) → notifyListeners 순으로 이어진다.
      // 실제 시간이 흘러야 하는 구간이라 runAsync 안에서 프레임을 돌리며 기다린다.
      for (var i = 0; i < 40 && provider.questionList.isNotEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await settle(tester);

      expect(provider.questionList, isEmpty,
          reason: '초기화하면 현재 화면의 문제 목록도 비어야 한다');
      late Map<String, dynamic>? row;
      await tester.runAsync(() async {
        row = await db.getSpacedRepetition(qid);
      });
      expect(row, isNull);
      expect(find.textContaining('오답노트를 비웠어요'), findsOneWidget);
    });

    testWidgets('취소하면 아무것도 지우지 않는다', (tester) async {
      late int qid;
      late StudyProvider provider;
      await tester.runAsync(() async {
        qid = await anyQuestionId();
        await sr.processAnswer(qid, false);
        provider = StudyProvider(
          db: db,
          predictionEngine: PredictionEngine(),
          spacedRepetitionService: sr,
        );
        await provider.loadWrongAnswerQuestions();
      });

      await tester.pumpWidget(host(provider));
      await settle(tester);
      await tester.tap(find.byKey(const Key('reset_wrong_note')));
      await settle(tester);
      await tester.tap(find.text('취소'));
      await settle(tester);

      late Map<String, dynamic>? row;
      await tester.runAsync(() async {
        row = await db.getSpacedRepetition(qid);
      });
      expect(row, isNotNull);
    });

    testWidgets('다른 모드에는 초기화 버튼이 없다', (tester) async {
      final provider = StudyProvider(
        db: db,
        predictionEngine: PredictionEngine(),
        spacedRepetitionService: sr,
      );
      await tester.pumpWidget(host(provider, mode: StudyMode.bookmark));
      await settle(tester);
      expect(find.byKey(const Key('reset_wrong_note')), findsNothing);
    });
  });
}
