import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/screens/subscription_screen.dart';
import 'package:gisa_pass_master/services/ai_exam_quota.dart';
import 'package:gisa_pass_master/services/plan_reset_quota.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/utils/price_format.dart';

/// 구독 화면 **판매 문구 사실성** 검증.
///
/// 가격은 화면에 '₩4,900' 이 박혀 있어 AppConfig.premiumPrice 를 고쳐도
/// 따라오지 않았고, 기능표는 무료도 하루 1회 쓸 수 있는 모의고사를 × 로 적고
/// 있었다. 표기와 실제 게이팅이 다르면 결제 화면에서 곧장 분쟁이 된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppConfig.nowForTest = null);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PurchaseService>(
        create: (_) => PurchaseService(),
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('가격은 정본에서 만든 문자열을 그린다', (tester) async {
    AppConfig.nowForTest = () => DateTime(2026, 9, 22);

    await pumpScreen(tester);

    // 플랜 타일의 가격은 RichText(TextSpan) 이라 findRichText 가 필요하다.
    expect(find.text(formatPrice(AppConfig.premiumPrice), findRichText: true),
        findsWidgets);
    expect(find.text(formatPrice(0), findRichText: true), findsWidgets,
        reason: '무료 플랜도 같은 정본');
  });

  testWidgets('기능표의 횟수는 게이팅 정본 숫자를 쓴다', (tester) async {
    AppConfig.nowForTest = () => DateTime(2026, 9, 22);

    await pumpScreen(tester);

    // 무료도 쓸 수 있는 기능을 × 로 적으면 거짓 표기다. 숫자가 코드와
    // 어긋날 수 없도록 쿼터 상수를 그대로 화면에서 찾는다.
    expect(find.text('하루 ${AiExamQuota.freeAttemptsPerDay}회'), findsWidgets);
    expect(find.text('하루 ${AiExamQuota.maxBonusPerDay}회'), findsOneWidget);
    expect(find.text('하루 ${PlanResetQuota.freeResetsPerDay}회'), findsWidgets);
  });

  testWidgets('시험이 가까우면 무료 한도와 D-Day 를 사실대로 적는다', (tester) async {
    AppConfig.nowForTest = () => DateTime(2026, 9, 22); // 시험 2026-10-18 확정
    expect(AppConfig.daysUntilExam, 26, reason: '테스트 전제 확인');

    await pumpScreen(tester);

    expect(find.textContaining('D-${AppConfig.daysUntilExam}'), findsOneWidget);
  });

  testWidgets('시험이 60일 넘게 남으면 D-Day 문구를 쓰지 않는다', (tester) async {
    AppConfig.nowForTest = () => DateTime(2026, 7, 6);
    expect(AppConfig.daysUntilExam, greaterThan(60), reason: '테스트 전제 확인');

    await pumpScreen(tester);

    expect(find.textContaining('D-'), findsNothing);
  });

  testWidgets('확정 일정이 아니면 D-Day 문구를 쓰지 않는다', (tester) async {
    AppConfig.nowForTest = () => DateTime(2027, 6, 1);
    expect(AppConfig.isExamDateConfirmed, isFalse, reason: '테스트 전제 확인');

    await pumpScreen(tester);

    expect(find.textContaining('D-'), findsNothing);
  });
}
