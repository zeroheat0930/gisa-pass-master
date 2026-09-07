import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/widgets/banner_ad_bar.dart';

/// 배너는 각 화면이 initState 에서 한 번 만들기 때문에, 화면을 띄운 채로
/// 결제를 마치면 이미 로드된 배너가 방금 결제한 유저에게 계속 보였다.
/// BannerAdBar 는 표시 지점에서 프리미엄을 구독해 그 순간 사라져야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(PurchaseService service, {BannerAd? ad, required bool loaded}) {
    return ChangeNotifierProvider<PurchaseService>.value(
      value: service,
      child: MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BannerAdBar(bannerAd: ad, loaded: loaded),
        ),
      ),
    );
  }

  // load() 를 부르지 않으므로 플랫폼 채널 없이 순수 Dart 객체로 남는다.
  BannerAd bareAd() => BannerAd(
        adUnitId: 'test',
        size: AdSize.banner,
        request: const AdRequest(),
        listener: const BannerAdListener(),
      );

  testWidgets('프리미엄이면 로드된 배너가 있어도 그리지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();
    await service.grantPremium();

    await tester.pumpWidget(host(service, ad: bareAd(), loaded: true));

    expect(find.byType(AdWidget), findsNothing,
        reason: '"광고 제거"는 구독 화면이 약속한 유료 혜택이다 — '
            '결제 직후 첫 화면부터 배너가 없어야 한다');
  });

  testWidgets('화면을 띄운 채 결제해도 배너가 즉시 사라진다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();

    // 무료 유저로 진입 (배너 미로드 상태 — AdWidget 렌더링은 실기기 전용)
    await tester.pumpWidget(host(service, ad: bareAd(), loaded: false));
    expect(find.byType(AdWidget), findsNothing);

    // 화면이 떠 있는 동안 결제 완료 → notifyListeners 가 이 위젯을 다시 그려야 한다
    await service.grantPremium();
    await tester.pump();

    expect(service.isPremium, isTrue);
    expect(find.byType(AdWidget), findsNothing);
  });

  testWidgets('배너가 아직 없으면 아무것도 그리지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();

    await tester.pumpWidget(host(service, ad: null, loaded: false));

    expect(find.byType(AdWidget), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // shrink 자리만 남는다
  });
}
