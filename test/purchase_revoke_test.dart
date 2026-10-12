import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';

PurchaseDetails _purchase(PurchaseStatus status) {
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
  p.pendingCompletePurchase = true;
  return p;
}

/// Android 복원 경로로 내려오는 구매 (플러그인은 status 를 restored 로 덮어쓴다).
GooglePlayPurchaseDetails _androidRestored(PurchaseStateWrapper state) {
  final wrapper = PurchaseWrapper(
    orderId: 'GPA.0000',
    packageName: 'com.gisapass.gisaPassMaster',
    purchaseTime: 0,
    purchaseToken: 'token-1',
    signature: 'sig',
    products: const [PurchaseService.premiumMonthlyId],
    isAutoRenewing: false,
    originalJson: '{}',
    isAcknowledged: true,
    purchaseState: state,
  );
  return GooglePlayPurchaseDetails.fromPurchase(wrapper).single
    ..status = PurchaseStatus.restored;
}

/// 캐시된 프리미엄으로 '앱을 켠' 서비스. 복원 호출은 [snapshot] 을 스트림에
/// 흘려보내는 플러그인 동작(0.5.2: 성공하면 빈 목록도 add)을 흉내 낸다.
Future<PurchaseService> _launch({
  required List<PurchaseDetails>? snapshot,
  AdService? adService,
}) async {
  final service = PurchaseService();
  if (adService != null) service.setAdService(adService);
  service.completePurchaseForTest = (_) async {};
  await service.restoreCachedPremium();
  service.restorePurchasesForTest = () async {
    if (snapshot == null) throw StateError('BillingResponse.serviceUnavailable');
    service.handlePurchaseUpdates(snapshot);
  };
  return service;
}

/// 환불·취소 회수 (Android).
///
/// 프리미엄 캐시를 false 로 되돌리는 경로가 없으면 Play 48시간 셀프 환불 뒤에도
/// 프리미엄이 영구히 남는다. 반대로 회수가 헐거우면 **정상 구매자를 무료로
/// 강등**한다 — 이쪽이 훨씬 해롭다. 그래서 '오프라인·예외면 유지',
/// '연속 2회 빈 결과일 때만 회수', '이 세션에 막 지급됐으면 유지'를 모두 건다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android 시작 복원 — 환불·취소 회수', () {
    test('빈 복원 결과가 두 번 연속이면 회수하고 광고를 되살린다', () async {
      SharedPreferences.setMockInitialValues({'premium_purchased': true});

      // 1회차 실행: 빈 결과 한 번으로는 회수하지 않는다(일시 상태일 수 있다).
      final first = await _launch(snapshot: []);
      await first.runAndroidStartupRestore();
      await pumpEventQueue();
      expect(first.isPremium, isTrue,
          reason: '빈 결과 한 번으로 회수하면 계정 전환 직후 같은 일시 상태에 정상 구매자가 강등된다');

      // 2회차 실행: 또 비었으면 회수.
      final adService = AdService()..setPremium(true);
      final second = await _launch(snapshot: [], adService: adService);
      expect(second.isPremium, isTrue, reason: '전제: 캐시로 켜진 상태');
      await second.runAndroidStartupRestore();
      await pumpEventQueue();

      expect(second.isPremium, isFalse, reason: '환불된 구매는 회수돼야 한다');
      expect(second.premiumRevoked, isTrue, reason: '구독 화면에 복원 안내를 띄울 근거');
      expect(adService.shouldShowAds, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('premium_purchased'), isNot(true),
          reason: '캐시를 지우지 않으면 다음 실행에 다시 켜진다');

      // 3회차 실행: 회수가 유지되고 안내 표시가 남아 있다.
      final third = PurchaseService();
      await third.restoreCachedPremium();
      expect(third.isPremium, isFalse);
      expect(third.premiumRevoked, isTrue);
    });

    test('복원 결과에 프리미엄이 있으면 유지하고 빈 결과 횟수를 리셋한다', () async {
      SharedPreferences.setMockInitialValues({'premium_purchased': true});

      final a = await _launch(snapshot: []);
      await a.runAndroidStartupRestore();
      await pumpEventQueue();

      final b = await _launch(
          snapshot: [_androidRestored(PurchaseStateWrapper.purchased)]);
      await b.runAndroidStartupRestore();
      await pumpEventQueue();
      expect(b.isPremium, isTrue);

      // 리셋됐으므로 다음 빈 결과 한 번으로는 회수되지 않는다.
      final c = await _launch(snapshot: []);
      await c.runAndroidStartupRestore();
      await pumpEventQueue();
      expect(c.isPremium, isTrue,
          reason: '띄엄띄엄 난 빈 결과를 누적하면 일시 장애 두 번에 정상 구매자가 강등된다');
    });

    test('복원이 예외로 끝나면(오프라인·스토어 장애) 몇 번이든 유지한다', () async {
      SharedPreferences.setMockInitialValues({'premium_purchased': true});

      for (var i = 0; i < 3; i++) {
        final service = await _launch(snapshot: null);
        await expectLater(service.runAndroidStartupRestore(), throwsStateError);
        // 예외 뒤 늦게 오는 무관한 빈 이벤트를 스냅샷으로 오인하면 안 된다.
        service.handlePurchaseUpdates([]);
        await pumpEventQueue();
        expect(service.isPremium, isTrue, reason: '스토어 응답이 없으면 회수 근거가 없다');
      }
    });

    test('복원 요청 직후 결제가 끝나면 늦게 온 빈 결과로 회수하지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'premium_purchased': true,
        'premium_empty_restore_strikes': 1,
      });

      final service = await _launch(snapshot: null);
      // 복원 요청은 접수됐지만 결과는 아직 안 왔다.
      service.restorePurchasesForTest = () async {};
      await service.runAndroidStartupRestore();

      // 그 사이 결제 완료 → 지급. 결제 전 시점의 빈 스냅샷이 뒤늦게 도착한다.
      service.handlePurchaseUpdates([_purchase(PurchaseStatus.purchased)]);
      await pumpEventQueue();
      service.handlePurchaseUpdates([]);
      await pumpEventQueue();

      expect(service.isPremium, isTrue, reason: '방금 돈 낸 유저를 강등하면 최악이다');
    });

    test('결제 이벤트(purchased)는 복원 스냅샷으로 취급하지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'premium_purchased': true,
        'premium_empty_restore_strikes': 1,
      });

      final service = await _launch(snapshot: null);
      service.restorePurchasesForTest = () async {};
      await service.runAndroidStartupRestore();

      // 다른 상품 결제가 섞인 이벤트 — 전부-restored 가 아니면 스냅샷이 아니다.
      final other = PurchaseDetails(
        productID: 'some_other_product',
        verificationData: PurchaseVerificationData(
            localVerificationData: '', serverVerificationData: '', source: ''),
        transactionDate: '0',
        status: PurchaseStatus.purchased,
      );
      service.handlePurchaseUpdates([other]);
      await pumpEventQueue();
      expect(service.isPremium, isTrue);
    });

    test('회수 뒤 복원에 성공하면 안내 표시가 사라진다', () async {
      SharedPreferences.setMockInitialValues({'premium_revoked_notice': true});

      final service = PurchaseService()..completePurchaseForTest = (_) async {};
      await service.restoreCachedPremium();
      expect(service.premiumRevoked, isTrue);

      service.handlePurchaseUpdates(
          [_androidRestored(PurchaseStateWrapper.purchased)]);
      await pumpEventQueue();

      expect(service.isPremium, isTrue);
      expect(service.premiumRevoked, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('premium_revoked_notice'), isNot(true));
    });
  });

  group('결제 승인 대기(pending)', () {
    test('pending 이 오면 승인 대기, purchased 가 오면 해제된다', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService()..completePurchaseForTest = (_) async {};

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.pending)]);
      expect(service.isPendingApproval, isTrue);
      expect(service.isPremium, isFalse, reason: '승인 전에는 지급하지 않는다');

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.purchased)]);
      await pumpEventQueue();
      expect(service.isPendingApproval, isFalse);
      expect(service.isPremium, isTrue);
    });

    for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
      test('$status 가 오면 승인 대기가 해제된다', () async {
        SharedPreferences.setMockInitialValues({});
        final service = PurchaseService()
          ..completePurchaseForTest = (_) async {};

        service.handlePurchaseUpdates([_purchase(PurchaseStatus.pending)]);
        service.handlePurchaseUpdates([_purchase(status)]);
        await pumpEventQueue();

        expect(service.isPendingApproval, isFalse);
      });
    }

    test('재시작 후 Android 복원으로 온 PENDING 구매도 승인 대기로 보인다', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService()..completePurchaseForTest = (_) async {};

      service.handlePurchaseUpdates(
          [_androidRestored(PurchaseStateWrapper.pending)]);
      await pumpEventQueue();

      expect(service.isPendingApproval, isTrue);
      expect(service.isPremium, isFalse);
    });
  });

  group('유저에게 보여줄 에러 사건', () {
    test('스트림으로 온 결제 실패는 같은 문구라도 매번 새 사건으로 센다', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService()..completePurchaseForTest = (_) async {};
      final before = service.purchaseErrorSerial;

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.error)]);
      service.handlePurchaseUpdates([_purchase(PurchaseStatus.error)]);
      await pumpEventQueue();

      expect(service.purchaseErrorSerial, before + 2);
      expect(service.error, isNotNull);
    });

    test('취소는 에러 사건이 아니다', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService()..completePurchaseForTest = (_) async {};
      final before = service.purchaseErrorSerial;

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.canceled)]);
      await pumpEventQueue();

      expect(service.purchaseErrorSerial, before);
    });
  });

  group('waitForPremium', () {
    test('기다리는 중에 프리미엄이 켜지면 true', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService();

      final result = service.waitForPremium(const Duration(seconds: 5));
      await service.grantPremium();

      expect(await result, isTrue);
    });

    test('시간 안에 안 켜지면 false', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PurchaseService();

      expect(await service.waitForPremium(const Duration(milliseconds: 20)),
          isFalse);
    });
  });

  test('purchaseStream 구독은 여러 번 불러도 안전하다', () {
    final service = PurchaseService();
    service.listenToPurchaseStream();
    service.listenToPurchaseStream();
    service.dispose();
  });
}
