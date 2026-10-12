import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/screens/subscription_screen.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';

PurchaseDetails _purchase(PurchaseStatus status, {String? message}) {
  final p = PurchaseDetails(
    purchaseID: 'txn-1',
    productID: PurchaseService.premiumMonthlyId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '0',
    status: status,
  );
  if (message != null) {
    p.error = IAPError(source: 'test', code: 'e', message: message);
  }
  p.pendingCompletePurchase = true;
  return p;
}

/// 구독 화면의 **결제 결과 피드백**.
///
/// 스토어 결과는 버튼 핸들러가 끝난 뒤 스트림으로 늦게 온다. 화면이 그걸
/// 듣지 않으면 결제 거절·승인 대기·복원 결과가 유저에게 아무것도 안 보인다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PurchaseService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = PurchaseService()..completePurchaseForTest = (_) async {};
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PurchaseService>.value(
        value: service,
        child: const MaterialApp(home: SubscriptionScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> tapRestore(WidgetTester tester) async {
    await tester.ensureVisible(find.text('구매 복원'));
    await tester.tap(find.text('구매 복원'));
    await tester.pump();
  }

  testWidgets('스트림으로 늦게 온 결제 실패를 스낵바로 한 번 보여준다', (tester) async {
    await pumpScreen(tester);

    service.handlePurchaseUpdates(
        [_purchase(PurchaseStatus.error, message: '카드가 거절됐습니다')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('카드가 거절됐습니다'), findsOneWidget);

    // 에러와 무관한 변화(재빌드)로 같은 스낵바가 다시 뜨면 안 된다.
    service.handlePurchaseUpdates([_purchase(PurchaseStatus.pending)]);
    await tester.pump();
    expect(find.text('카드가 거절됐습니다'), findsOneWidget);
  });

  testWidgets('화면에 들어오기 전에 난 에러는 띄우지 않는다', (tester) async {
    service.handlePurchaseUpdates(
        [_purchase(PurchaseStatus.error, message: '옛 에러')]);
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('옛 에러'), findsNothing);
  });

  testWidgets('승인 대기 안내를 보이고, 결제 버튼은 그대로 눌린다', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('결제 승인 대기 중'), findsNothing);

    service.handlePurchaseUpdates([_purchase(PurchaseStatus.pending)]);
    await tester.pump();

    expect(find.text('결제 승인 대기 중이에요. 승인되면 자동으로 적용됩니다'),
        findsOneWidget);
    expect(find.text('프리미엄 시작하기'), findsOneWidget,
        reason: '승인이 거절되면 다시 결제할 길이 있어야 한다');

    service.handlePurchaseUpdates([_purchase(PurchaseStatus.purchased)]);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('결제 승인 대기 중'), findsNothing);
    expect(find.text('프리미엄 이용 중'), findsOneWidget);
  });

  testWidgets('복원 요청 뒤 프리미엄이 켜지면 "복원됐어요"', (tester) async {
    service.debugSetAvailable(true);
    service.restorePurchasesForTest = () async {
      // 결과는 요청이 끝난 뒤 스트림으로 온다.
      Future.delayed(const Duration(seconds: 1), () {
        service.handlePurchaseUpdates([_purchase(PurchaseStatus.restored)]);
      });
    };
    await pumpScreen(tester);

    await tapRestore(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('복원됐어요'), findsOneWidget);
  });

  testWidgets('복원할 구매가 없으면 약 5초 뒤 계정 확인 안내', (tester) async {
    service.debugSetAvailable(true);
    service.restorePurchasesForTest = () async {};
    await pumpScreen(tester);

    await tapRestore(tester);
    expect(find.textContaining('복원할 구매를 찾지 못했어요'), findsNothing,
        reason: '기다리기 전에 실패로 단정하면 안 된다');

    await tester.pump(SubscriptionScreen.restoreWait);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.text('복원할 구매를 찾지 못했어요. 구매한 계정으로 로그인돼 있는지 확인해주세요'),
        findsOneWidget);
  });

  testWidgets('복원 요청 자체가 실패하면 에러를 한 번만 보여준다', (tester) async {
    service.debugSetAvailable(true);
    service.restorePurchasesForTest = () async => throw StateError('offline');
    await pumpScreen(tester);

    await tapRestore(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('구매 복원에 실패했습니다. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    expect(find.textContaining('복원할 구매를 찾지 못했어요'), findsNothing);
  });

  testWidgets('회수된 유저에게 구매 복원 안내를 이번 진입에만 보여준다', (tester) async {
    SharedPreferences.setMockInitialValues({'premium_revoked_notice': true});
    service = PurchaseService();
    await service.restoreCachedPremium();

    await pumpScreen(tester);
    expect(find.textContaining('프리미엄이 해제됐어요'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('premium_revoked_notice'), isNot(true),
        reason: '일부러 환불한 유저에게 매번 띄울 이유는 없다');
  });
}
