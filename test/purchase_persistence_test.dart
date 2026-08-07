import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';

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
