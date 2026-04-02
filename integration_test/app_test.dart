import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:gisa_pass_master/main.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';
import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late AdService adService;
  late PurchaseService purchaseService;

  setUp(() {
    db = DatabaseService();
    adService = AdService();
    purchaseService = PurchaseService()..setAdService(adService);
  });

  Widget buildApp() {
    return GisaPassMasterApp(
      db: db,
      predictionEngine: PredictionEngine(),
      spacedRepetitionService: SpacedRepetitionService(db),
      adService: adService,
      purchaseService: purchaseService,
    );
  }

  // ─── 시나리오 1: 제출 버튼 20번 연타 (비동기 충돌 체크) ───
  testWidgets('연타 테스트: 제출 버튼 20번 연속 탭해도 크래시 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // "예측 학습 시작" 버튼 찾기
    final predictionBtn = find.text('예측 학습 시작');
    if (predictionBtn.evaluate().isNotEmpty) {
      await tester.tap(predictionBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 답안 입력 필드 찾기
      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField.first, 'test');

        // 제출 버튼 찾기
        final submitBtn = find.text('제출');
        if (submitBtn.evaluate().isNotEmpty) {
          // 20번 연타!
          for (int i = 0; i < 20; i++) {
            await tester.tap(submitBtn, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }
      }
    }
    // 크래시 없이 여기까지 도달하면 성공
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // ─── 시나리오 2: 5문제 풀기 후 광고 플래그 확인 ───
  testWidgets('5문제 풀면 shouldShowAd 플래그 활성화', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Provider에서 StudyProvider 접근
    final context = tester.element(find.byType(MaterialApp));
    final provider = Provider.of<StudyProvider>(context, listen: false);

    // 문제 로드
    await provider.loadQuestions();
    await tester.pumpAndSettle();

    // 5문제 연속 제출
    int adTriggered = 0;
    for (int i = 0; i < 5; i++) {
      if (provider.currentQuestion == null) break;
      await provider.submitAnswer('test_answer_$i');
      if (provider.shouldShowAd) {
        adTriggered++;
        provider.clearAdFlag();
      }
      provider.nextQuestion();
    }

    // 5문제마다 광고 트리거 (adIntervalQuestions = 5)
    expect(adTriggered, greaterThanOrEqualTo(1));
  });

  // ─── 시나리오 3: 뒤로가기 크래시 체크 ───
  testWidgets('퀴즈 화면에서 뒤로가기 시 크래시 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 예측 학습 시작
    final predictionBtn = find.text('예측 학습 시작');
    if (predictionBtn.evaluate().isNotEmpty) {
      await tester.tap(predictionBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 뒤로가기 (AppBar back button)
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await tester.pumpAndSettle();
      } else {
        // Navigator pop 직접 실행
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await tester.pumpAndSettle();
      }
    }

    // 홈 화면으로 복귀 확인
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // ─── 시나리오 4: 탭 왕복 50회 메모리 릭 체크 ───
  testWidgets('탭 50회 왕복 전환해도 크래시/흰화면 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // NavigationBar의 탭들을 찾기
    final tabs = ['홈', '기출문제', '족보', '통계'];

    for (int round = 0; round < 50; round++) {
      final tabIndex = round % 4;
      final tabFinder = find.text(tabs[tabIndex]);
      if (tabFinder.evaluate().isNotEmpty) {
        await tester.tap(tabFinder.last);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 앱이 살아있고 위젯 트리가 정상인지 확인
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
