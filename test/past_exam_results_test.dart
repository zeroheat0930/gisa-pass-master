import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';
import 'package:gisa_pass_master/screens/past_exam_screen.dart';
import 'package:gisa_pass_master/services/ai_exam_quota.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/services/review_prompt_service.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';

/// 복원 기출 결과 화면 = 무료 트래픽이 가장 크게 모이는 화면인데 유료 입구가
/// 하나도 없었다. 여기서 검증하는 것은 셋이다.
///  1) 유료 CTA 2개가 실제로 보이고, 프리미엄에게는 구독 CTA 가 사라진다.
///  2) 연타해도 화면이 두 번 쌓이지 않는다(무료 응시 2회 소모 사고의 재현 경로).
///  3) 리뷰 요청과 쿼터 소진 다이얼로그가 겹치지 않는다.
class _FakePurchaseService extends PurchaseService {
  _FakePurchaseService({required bool premium}) : _premium = premium;
  final bool _premium;

  @override
  bool get isPremium => _premium;
}

/// DB·예측엔진을 타지 않는 StudyProvider. 결과 화면 검증에 풀이 기록은 필요 없다.
class _FakeStudyProvider extends StudyProvider {
  _FakeStudyProvider._(DatabaseService db)
      : super(
          db: db,
          predictionEngine: PredictionEngine(),
          spacedRepetitionService: SpacedRepetitionService(db),
        );

  factory _FakeStudyProvider() => _FakeStudyProvider._(DatabaseService());

  @override
  Future<void> recordAnswer({
    required Question question,
    required String userAnswer,
    required bool isCorrect,
  }) async {}

  @override
  Future<void> loadQuestions() async {}

  @override
  List<Question> get questionList => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const answer = '정규화';

  Question question(int id) => Question(
        id: id,
        year: 2025,
        round: 1,
        subject: '데이터베이스',
        questionType: 'short_answer',
        questionText: '테스트 문항 $id',
        answer: answer,
        explanation: '해설',
        source: Question.sourceRestored,
      );

  int reviewCalls = 0;

  setUp(() {
    reviewCalls = 0;
    SharedPreferences.setMockInitialValues({});
    ReviewPromptService.debugOpenStoreReview = () async {
      reviewCalls++;
      return true;
    };
  });

  tearDown(() => ReviewPromptService.debugOpenStoreReview = null);

  /// 기본 테스트 화면(800×600)에서는 결과 화면 하단 CTA 가 스크롤 밖으로
  /// 밀려 탭이 빗나간다. 탭 판정을 위해 뷰포트를 길게 잡는다.
  void tallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host({required bool premium, int questionCount = 1}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PurchaseService>.value(
          value: _FakePurchaseService(premium: premium),
        ),
        ChangeNotifierProvider<StudyProvider>.value(value: _FakeStudyProvider()),
      ],
      child: MaterialApp(
        home: buildPastExamQuiz(
          questions: List.generate(questionCount, question),
          title: '복원 기출',
        ),
      ),
    );
  }

  /// 결과 화면까지 실제로 풀어서 도달한다. 결과 화면만 따로 만들 수 없어서
  /// (private 위젯) 진입 경로를 그대로 탄다.
  ///
  /// 풀이 화면에는 1초 주기 타이머가 살아 있어 pumpAndSettle 이 끝나지 않는다.
  /// 결과 화면에서 타이머가 꺼지므로 그전까지는 pump() 로만 진행한다.
  Future<void> finishQuiz(WidgetTester tester,
      {required int questionCount, required bool correct}) async {
    for (var i = 0; i < questionCount; i++) {
      await tester.enterText(
          find.byType(TextField).first, correct ? answer : '오답');
      await tester.pump();
      await tester.tap(find.text('제출'));
      await tester.pump();
      await tester.tap(find.text(i + 1 >= questionCount ? '결과 보기' : '다음 문제'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  group('유료 CTA (P0)', () {
    testWidgets('무료 유저에게 CTA 2개를 보여준다', (tester) async {
      await tester.pumpWidget(host(premium: false));
      await finishQuiz(tester, questionCount: 1, correct: false);

      expect(find.text('AI 실전 모의고사로 실력 점검'), findsOneWidget);
      expect(find.text('광고 없이 공부에 집중'), findsOneWidget);
    });

    testWidgets('프리미엄에게는 구독 CTA 를 감춘다', (tester) async {
      await tester.pumpWidget(host(premium: true));
      await finishQuiz(tester, questionCount: 1, correct: false);

      expect(find.text('AI 실전 모의고사로 실력 점검'), findsOneWidget);
      expect(find.text('광고 없이 공부에 집중'), findsNothing,
          reason: '산 사람에게 계속 팔면 안 된다');
    });

    testWidgets('연속 2회 탭해도 화면은 한 번만 열린다', (tester) async {
      tallViewport(tester);
      final observer = _PushCounter();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PurchaseService>.value(
              value: _FakePurchaseService(premium: false),
            ),
            ChangeNotifierProvider<StudyProvider>.value(
              value: _FakeStudyProvider(),
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            home: buildPastExamQuiz(
              questions: [question(1)],
              title: '복원 기출',
            ),
          ),
        ),
      );
      await finishQuiz(tester, questionCount: 1, correct: false);

      observer.pushes = 0;
      // 핸들러를 직접 두 번 부른다. tester.tap 을 두 번 부르면 그 사이에 프레임이
      // 돌아 첫 탭이 띄운 화면·배리어가 두 번째 탭을 가로채므로, 정작 재현하려는
      // "첫 탭의 await 가 끝나기 전에 두 번째 탭이 들어온다"가 재현되지 않는다.
      final onPressed = tester
          .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '광고 없이 공부에 집중'))
          .onPressed!;
      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(observer.pushes, 1, reason: '이중 탭으로 화면이 두 번 쌓이면 안 된다');
    });

    testWidgets('AI CTA 를 연타해도 쿼터 다이얼로그는 하나만 뜬다', (tester) async {
      tallViewport(tester);
      await AiExamQuota.consume(isPremium: false); // 오늘 무료 1회 소진

      await tester.pumpWidget(host(premium: false));
      await finishQuiz(tester, questionCount: 1, correct: false);

      final onPressed = tester
          .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'AI 실전 모의고사로 실력 점검'))
          .onPressed!;
      onPressed();
      onPressed();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'canStart 의 await 앞에 가드가 없으면 다이얼로그가 두 겹으로 쌓인다');
      expect(find.text('오늘의 무료 모의고사 완료'), findsOneWidget);
    });
  });

  group('실전 환산 (P3-lite)', () {
    test('문항 수에 비례한다 — 5·20·40 문항 = 37.5·150·300분', () {
      expect(realExamLimitFor(5).inSeconds / 60, 37.5);
      expect(realExamLimitFor(20).inSeconds / 60, 150);
      expect(realExamLimitFor(40).inSeconds / 60, 300);
    });

    test('기준 시간 1초 전은 환산, 1초 후는 초과', () {
      final limit = realExamLimitFor(20);
      expect(
        realExamPaceLabel(
            questionCount: 20,
            elapsed: limit - const Duration(seconds: 1)),
        '실전 환산: 20문항 기준 150분 중 149분 사용',
      );
      expect(
        realExamPaceLabel(
            questionCount: 20,
            elapsed: limit + const Duration(seconds: 1)),
        '실전 환산: 20문항 기준 150분 — 기준 시간 초과',
      );
      expect(
        realExamPaceLabel(questionCount: 20, elapsed: limit),
        contains('중 150분 사용'),
        reason: '정확히 기준 시간이면 초과가 아니다',
      );
    });

    test('소수 분이 나오는 문항 수도 정직하게 쓴다', () {
      expect(
        realExamPaceLabel(questionCount: 5, elapsed: Duration.zero),
        '실전 환산: 5문항 기준 37.5분 중 0분 사용',
      );
    });

    testWidgets('결과 화면에 환산 문구가 보인다', (tester) async {
      await tester.pumpWidget(host(premium: false));
      await finishQuiz(tester, questionCount: 1, correct: false);

      expect(find.textContaining('실전 환산: 1문항 기준 7.5분'), findsOneWidget);
    });
  });

  group('리뷰 요청 상호배제 (P4)', () {
    testWidgets('조건을 채우면 한 번 요청하고, 재빌드해도 더 묻지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 100,
      });

      await tester.pumpWidget(host(premium: false));
      await finishQuiz(tester, questionCount: 1, correct: true);

      expect(reviewCalls, 1);

      await tester.pump();
      await tester.pumpAndSettle();
      expect(reviewCalls, 1, reason: '재빌드마다 물으면 그 유저에게는 다시 못 묻는다');
    });

    testWidgets('정답률이 낮으면 묻지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 100,
      });

      await tester.pumpWidget(host(premium: false));
      await finishQuiz(tester, questionCount: 1, correct: false);

      expect(reviewCalls, 0);
    });

    testWidgets('쿼터 소진 다이얼로그와 리뷰가 겹치지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 100,
      });
      await AiExamQuota.consume(isPremium: false);

      tallViewport(tester);
      await tester.pumpWidget(host(premium: false));
      // 오답 세션이라 진입 시점에는 리뷰 조건이 아니다.
      await finishQuiz(tester, questionCount: 1, correct: false);
      expect(reviewCalls, 0);

      await tester.tap(find.text('AI 실전 모의고사로 실력 점검'));
      await tester.pumpAndSettle();

      expect(find.text('오늘의 무료 모의고사 완료'), findsOneWidget);
      expect(reviewCalls, 0, reason: '다이얼로그가 겹치면 둘 다 무시당하고 별점만 깎인다');
    });
  });
}

class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
