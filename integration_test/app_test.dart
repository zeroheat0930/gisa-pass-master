import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:gisa_pass_master/main.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';
import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/services/study_plan_service.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';


/// D-Day 타이머가 1초마다 setState 를 호출하므로, 이 앱에서는 pumpAndSettle 이
/// 영원히 끝나지 않는다(프레임 스케줄이 비지 않는다). 그래서 통합 테스트가
/// 첫 시나리오에서 멈춰 있었고, 사실상 한 번도 실행된 적이 없었다.
/// 고정 횟수만큼 프레임을 진행시키는 방식으로 대체한다.
Future<void> settle(WidgetTester tester,
    [Duration total = const Duration(seconds: 2)]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

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
      studyPlanService: StudyPlanService(db),
    );
  }

  // ─── 시나리오 1: 제출 버튼 20번 연타 (비동기 충돌 체크) ───
  testWidgets('연타 테스트: 제출 버튼 20번 연속 탭해도 크래시 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    // "예측 학습 시작" 버튼 찾기
    final predictionBtn = find.text('예측 학습 시작');
    if (predictionBtn.evaluate().isNotEmpty) {
      await tester.tap(predictionBtn);
      await settle(tester, const Duration(seconds: 2));

      // 답안 입력 필드 찾기
      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField.first, 'test');

        // 제출 버튼 찾기
        final submitBtn = find.text('제출');
        expect(submitBtn, findsWidgets, reason: '제출 버튼을 찾지 못했다');

        // 좌표를 미리 잡아두고 그 지점을 20번 연타한다.
        // 위젯 파인더로 매번 다시 찾으면 안 된다 — 첫 제출 직후 버튼이 '다음'으로
        // 바뀌어 사라지므로 두 번째 탭에서 테스트가 터진다. 실제 유저의 연타는
        // '같은 화면 위치를 계속 누르는 것'이므로 좌표 탭이 현실에 가깝다.
        final point = tester.getCenter(submitBtn.first);
        for (int i = 0; i < 20; i++) {
          await tester.tapAt(point);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await settle(tester, const Duration(seconds: 1));
      }
    }
    // 크래시 없이 여기까지 도달하면 성공
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '연타 중 예외가 발생하면 안 된다');
  });

  // ─── 시나리오 2: 5문제 풀기 후 광고 플래그 확인 ───
  testWidgets('5문제 풀면 shouldShowAd 플래그 활성화', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    // Provider에서 StudyProvider 접근
    final context = tester.element(find.byType(MaterialApp));
    final provider = Provider.of<StudyProvider>(context, listen: false);

    // 문제 로드
    await provider.loadQuestions();
    await settle(tester);

    // 5문제 연속 제출
    int adTriggered = 0;
    for (int i = 0; i < 5; i++) {
      if (provider.currentQuestion == null) break;
      await provider.submitAnswer('test_answer_$i');
      // 광고 표시는 nextQuestion() 내부에서 일어난다(채점 직후에 띄우면
      // 정답/오답 이펙트를 덮으므로). 플래그는 그 전에 확인한다.
      if (provider.shouldShowAd) adTriggered++;
      provider.nextQuestion();
    }

    // adIntervalQuestions 문제마다 광고 트리거
    expect(adTriggered, greaterThanOrEqualTo(1));
  });

  // ─── 시나리오 3: 뒤로가기 크래시 체크 ───
  testWidgets('퀴즈 화면에서 뒤로가기 시 크래시 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    // 예측 학습 시작
    final predictionBtn = find.text('예측 학습 시작');
    if (predictionBtn.evaluate().isNotEmpty) {
      await tester.tap(predictionBtn);
      await settle(tester, const Duration(seconds: 2));

      // 뒤로가기 (AppBar back button)
      final backBtn = find.byType(BackButton);
      if (backBtn.evaluate().isNotEmpty) {
        await tester.tap(backBtn.first);
        await settle(tester);
      } else {
        // Navigator pop 직접 실행
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await settle(tester);
      }
    }

    // 홈 화면으로 복귀 확인
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // ─── 시나리오 4: 탭 왕복 50회 메모리 릭 체크 ───
  testWidgets('탭 50회 왕복 전환해도 크래시/흰화면 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    // NavigationBar 의 실제 라벨과 일치해야 한다.
    // 예전에는 '기출문제'로 되어 있었는데 실제 라벨은 '문제은행'이라 탭을 못 찾았고,
    // isNotEmpty 가드 때문에 아무 탭도 누르지 않은 채 테스트가 통과했다.
    final tabs = ['홈', '문제은행', '족보', '통계'];

    for (final label in tabs) {
      expect(find.text(label), findsWidgets, reason: '탭 라벨 "$label" 을 찾지 못했다');
    }

    for (int round = 0; round < 50; round++) {
      final tabIndex = round % 4;
      await tester.tap(find.text(tabs[tabIndex]).last);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle(tester, const Duration(seconds: 1));

    // 앱이 살아있고 위젯 트리가 정상인지 확인
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
