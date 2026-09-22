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

  // AdWidget 은 load() 되지 않은 광고를 트리에 넣으면 예외를 던지므로
  // (실기기 전용), 테스트에서는 이 자리표시로 "광고가 그려졌다"를 판정한다.
  const adMarker = Key('fake-ad');
  Widget fakeAd(BannerAd _) => const SizedBox(key: adMarker);

  Widget host(
    PurchaseService service, {
    BannerAd? ad,
    required bool loaded,
    Widget? body,
    double bottomInset = 0,
  }) {
    return ChangeNotifierProvider<PurchaseService>.value(
      value: service,
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: bottomInset),
            ),
            child: Scaffold(
              body: body,
              bottomNavigationBar: BannerAdBar(
                bannerAd: ad,
                loaded: loaded,
                adWidgetBuilder: fakeAd,
              ),
            ),
          ),
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

  testWidgets('무료 유저에게는 로드된 배너를 그린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();

    await tester.pumpWidget(host(service, ad: bareAd(), loaded: true));

    expect(find.byKey(adMarker), findsOneWidget,
        reason: '무료 유저의 배너는 광고 수익의 전부다 — 프리미엄 판정이 뒤집히면 안 된다');
  });

  testWidgets('프리미엄이면 로드된 배너가 있어도 그리지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();
    await service.grantPremium();

    await tester.pumpWidget(host(service, ad: bareAd(), loaded: true));

    expect(find.byKey(adMarker), findsNothing,
        reason: '"광고 제거"는 구독 화면이 약속한 유료 혜택이다 — '
            '결제 직후 첫 화면부터 배너가 없어야 한다');
  });

  testWidgets('화면을 띄운 채 결제해도 배너가 즉시 사라진다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();

    // 무료 유저로 진입 — 배너가 실제로 그려진 상태에서 시작해야
    // 결제 후 "사라졌다"가 프리미엄 구독 덕분임이 증명된다.
    await tester.pumpWidget(host(service, ad: bareAd(), loaded: true));
    expect(find.byKey(adMarker), findsOneWidget);

    // 화면이 떠 있는 동안 결제 완료 → notifyListeners 가 이 위젯을 다시 그려야 한다
    await service.grantPremium();
    await tester.pump();

    expect(service.isPremium, isTrue);
    expect(find.byKey(adMarker), findsNothing,
        reason: '결제 직후에도 배너가 남아 있으면 방금 결제한 유저에게 광고가 보인다');
  });

  testWidgets('배너가 아직 없으면 아무것도 그리지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();

    await tester.pumpWidget(host(service, ad: null, loaded: false));

    expect(find.byKey(adMarker), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // shrink 자리만 남는다
  });

  // Scaffold 는 bottomNavigationBar 자리가 비어 있지 않으면 body 의 하단
  // 안전영역 패딩을 걷어낸다. 배너를 숨길 때 SafeArea 없이 shrink 만 돌려주면
  // 화면 하단 버튼이 iPhone 홈 인디케이터 밑에 깔린다.
  testWidgets('배너를 숨겨도 하단 안전영역은 지킨다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = PurchaseService();
    await service.grantPremium();

    const bodyKey = Key('body');
    const inset = 34.0; // iPhone 홈 인디케이터
    await tester.pumpWidget(host(
      service,
      ad: bareAd(),
      loaded: true,
      body: const SizedBox.expand(key: bodyKey),
      bottomInset: inset,
    ));

    final bodyBottom = tester.getBottomLeft(find.byKey(bodyKey)).dy;
    final screenBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;
    expect(bodyBottom, lessThanOrEqualTo(screenBottom - inset),
        reason: '프리미엄 유저의 화면 하단이 홈 인디케이터에 깔리면 안 된다');
  });
}
