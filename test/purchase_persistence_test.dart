import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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

/// v1.5.4 회귀 방지:
/// 스토어는 completePurchase 로 종결된 트랜잭션을 앱 재시작 시 purchaseStream 으로
/// 다시 보내주지 않는다. 따라서 구매 사실을 기기에 영속 저장하지 않으면 평생 이용권을
/// 결제한 유저가 앱을 껐다 켤 때마다 프리미엄을 잃고 광고를 다시 보게 된다.
///
/// 읽기만 검증하면 저장 코드를 통째로 지워도 테스트가 통과한다. 쓰기·읽기 양쪽을 모두 건다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('프리미엄 영속성 — 쓰기', () {
    test('구매가 확정되면 기기에 실제로 저장된다', () async {
      SharedPreferences.setMockInitialValues({});

      final service = PurchaseService();
      await service.grantPremium();

      expect(service.isPremium, isTrue);

      // 저장 코드를 삭제하면 이 단언이 깨진다.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('premium_purchased'), isTrue,
          reason: '구매 사실이 기기에 저장되어야 한다');
    });

    test('구매 확정 시 광고가 즉시 꺼진다', () async {
      SharedPreferences.setMockInitialValues({});

      final adService = AdService();
      expect(adService.shouldShowAds, isTrue);

      final service = PurchaseService()..setAdService(adService);
      await service.grantPremium();

      expect(adService.shouldShowAds, isFalse);
    });
  });

  // 실제 결제가 흐르는 유일한 경로인 purchaseStream 핸들러의 배선.
  // 지금까지는 grantPremium(부품)만 직접 불러 검증해서, 핸들러가
  // grantPremium 을 부르지 않도록 되돌려도(v1.5.4 재판) 전부 통과했다.
  group('purchaseStream 핸들러 배선', () {
    test('purchased 콜백이 프리미엄 지급 → 저장 → 종결 순서로 이어진다', () async {
      SharedPreferences.setMockInitialValues({});

      final service = PurchaseService();
      final completed = <String>[];
      service.completePurchaseForTest = (p) async {
        // 종결 시점에는 이미 지급·저장이 끝나 있어야 한다. 순서가 뒤바뀌면
        // 저장 전에 앱이 죽었을 때 결제 유저가 프리미엄을 잃는다.
        expect(service.isPremium, isTrue,
            reason: '지급 전에 트랜잭션을 종결하면 안 된다');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('premium_purchased'), isTrue,
            reason: '저장 전에 트랜잭션을 종결하면 안 된다');
        completed.add(p.purchaseID ?? '');
      };

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.purchased)]);
      await pumpEventQueue();

      expect(service.isPremium, isTrue,
          reason: '결제 콜백이 프리미엄을 켜지 않으면 돈만 받고 물건을 안 준 것이다');
      expect(completed, ['txn-1'],
          reason: '저장 성공 후에는 트랜잭션을 종결해야 한다 '
              '(안 하면 Android 는 3일 후 자동 환불된다)');
    });

    test('restored 콜백도 동일하게 프리미엄을 복원한다', () async {
      SharedPreferences.setMockInitialValues({});

      final service = PurchaseService();
      service.completePurchaseForTest = (_) async {};

      service.handlePurchaseUpdates([_purchase(PurchaseStatus.restored)]);
      await pumpEventQueue();

      expect(service.isPremium, isTrue,
          reason: '복원 콜백이 무시되면 재설치 유저가 평생 이용권을 잃는다');
    });
  });

  group('프리미엄 영속성 — 읽기 (앱 재시작)', () {
    test('구매 → 재시작 왕복으로 프리미엄이 유지된다', () async {
      SharedPreferences.setMockInitialValues({});

      // 1회차 실행: 구매
      await PurchaseService().grantPremium();

      // 2회차 실행: 새 인스턴스가 저장된 값을 읽어 복원해야 한다
      final adService = AdService();
      final restarted = PurchaseService()..setAdService(adService);
      await restarted.initialize();

      expect(restarted.isPremium, isTrue, reason: '재시작 후에도 프리미엄이 유지되어야 한다');
      expect(adService.shouldShowAds, isFalse, reason: '결제 유저에게 광고가 나가면 안 된다');
    });

    test('구매 이력이 없으면 프리미엄이 아니다', () async {
      SharedPreferences.setMockInitialValues({});

      final service = PurchaseService();
      await service.initialize();

      expect(service.isPremium, isFalse);
    });

    test('스토어 연결에 실패해도 저장된 프리미엄은 유지된다', () async {
      // 이 테스트 환경에는 IAP 플랫폼 구현이 없어 isAvailable() 이 실패한다.
      // 오프라인/스토어 장애와 같은 경로이며, 이때도 프리미엄이 꺼지면 안 된다.
      SharedPreferences.setMockInitialValues({'premium_purchased': true});

      final service = PurchaseService();
      await service.initialize();

      expect(service.available, isFalse, reason: '스토어 연결은 실패한 상태');
      expect(service.isPremium, isTrue, reason: '그래도 프리미엄은 유지되어야 한다');
    });
  });
}
