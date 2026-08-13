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

  // 닿지 않은 탭을 **실패로 만든다.** 기본값은 경고만 찍고 통과시키는데,
  // 그 탓에 화면 밖으로 밀려난 버튼을 누른 시나리오가 아무것도 하지 않은 채
  // 한참 뒤 엉뚱한 단언에서 터졌다. 레이아웃이 바뀌면 여기서 즉시 걸린다.
  WidgetController.hitTestWarningShouldBeFatal = true;

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

  // 파인더가 나타날 때까지 기다린다. 조용한 `if (isNotEmpty)` 가드는 금물 —
  // 문제 로드가 느리면 시나리오 전체를 건너뛴 채 통과해서, 이 테스트가
  // 아무것도 검증하지 않고 20번 녹색이었던 적이 있다(감사 #25).
  Future<void> waitFor(WidgetTester tester, Finder finder, String what,
      [Duration timeout = const Duration(seconds: 15)]) async {
    const step = Duration(milliseconds: 200);
    for (var elapsed = Duration.zero; elapsed < timeout; elapsed += step) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('$timeout 안에 $what 이(가) 나타나지 않았다 — 시나리오가 공회전한다');
  }

  // 홈은 스크롤 화면이다. 위젯이 트리에 있다고 화면 안에 있는 것은 아니다.
  // 홈에 버튼이 하나 늘어나자 '예측 학습 시작' 이 화면 밖 41px 로 밀려났고,
  // `tap()` 은 아무 데도 닿지 않은 채 **경고만 찍고 조용히 성공했다.**
  // 그 뒤 단계가 전부 공회전해서야 실패가 드러났다.
  // 그러므로 홈에서 무언가를 누를 때는 반드시 이 함수로 누른다.
  Future<void> tapVisible(
      WidgetTester tester, Finder finder, String what) async {
    expect(finder, findsWidgets, reason: '$what 을(를) 찾지 못했다');
    await tester.ensureVisible(finder.first);
    await settle(tester);
    await tester.tap(finder.first);
  }

  // ─── 시나리오 1: 제출 버튼 20번 연타 (비동기 충돌 체크) ───
  testWidgets('연타 테스트: 제출 버튼 20번 연속 탭해도 크래시 없음', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    await tapVisible(tester, find.text('예측 학습 시작'), '홈의 예측 학습 카드');

    // 문제 로드는 DB 상태에 따라 수 초 걸릴 수 있다. 나타날 때까지 기다리고,
    // 안 나타나면 (건너뛰는 대신) 실패시킨다.
    await waitFor(tester, find.byType(TextField), '답안 입력창');
    await tester.enterText(find.byType(TextField).first, 'test');

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

    // 시나리오가 실제로 제출까지 도달했는지 확인한다. 이 단언이 없으면
    // 위의 어떤 단계가 조용히 실패해도 '크래시 없음'만 보고 통과한다.
    final context = tester.element(find.byType(MaterialApp));
    final provider = Provider.of<StudyProvider>(context, listen: false);
    expect(provider.sessionSolved, greaterThanOrEqualTo(1),
        reason: '연타 시나리오가 제출에 도달하지 못했다(공회전)');

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

    await tapVisible(tester, find.text('예측 학습 시작'), '홈의 예측 학습 카드');

    // 정말로 퀴즈까지 들어갔는지 확인하고 나서 되돌아온다. 이걸 안 보면
    // 화면 전환이 실패해도 '크래시 없음' 만 보고 통과한다.
    await waitFor(tester, find.byType(TextField), '답안 입력창');

    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn.first);
    } else {
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    }
    await settle(tester, const Duration(seconds: 2));

    // 홈으로 실제로 돌아왔는지 — MaterialApp 존재는 아무것도 증명하지 않는다.
    expect(find.text('예측 학습 시작'), findsWidgets,
        reason: '뒤로가기 후 홈으로 돌아오지 못했다');
    expect(tester.takeException(), isNull, reason: '뒤로가기에서 예외가 났다');
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

  // ─── 시나리오 5: 저작권 고지가 실제로 앱에 있다 ───
  //
  // 위젯 테스트는 이 위젯들을 따로 떼어 검사한다. 여기서 보는 것은
  // **조립된 진짜 앱에서 그 화면까지 실제로 도달하는가** 다. 배선이 빠지면
  // 부품 테스트는 전부 초록인데 앱에는 고지가 없는 상태가 된다.
  //
  // pub 패키지(BSD·MIT·Apache 2.0)가 배포물에 저작권 고지를 포함하라고
  // 요구하므로, 이 경로가 끊기면 라이선스 조건 미이행이다.
  testWidgets('홈에서 라이선스 고지 화면까지 실제로 갈 수 있다', (tester) async {
    await tester.pumpWidget(buildApp());
    await settle(tester, const Duration(seconds: 3));

    await tapVisible(tester, find.textContaining('오픈소스 라이선스'), '라이선스 고지 줄');
    await settle(tester, const Duration(seconds: 2));

    expect(find.byType(LicensePage), findsOneWidget,
        reason: '고지 화면이 열리지 않으면 오픈소스 라이선스 조건을 못 지킨 것이다');

    // 등록해둔 문항 출처 고지가 목록에 실제로 올라와 있는지 본다.
    await settle(tester, const Duration(seconds: 3));
    expect(find.textContaining('복원 기출'), findsWidgets,
        reason: 'CC BY 고지가 라이선스 목록에 등록되지 않았다');
  });
}
