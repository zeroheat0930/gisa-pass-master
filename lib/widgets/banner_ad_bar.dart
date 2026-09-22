import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';

/// 화면 하단 배너 광고 자리. Scaffold 의 bottomNavigationBar 에 넣는다.
///
/// 배너는 각 화면이 initState 에서 한 번 만들기 때문에, 화면을 띄운 채로
/// 결제를 마치면 이미 로드된 배너가 그대로 남아 방금 결제한 유저에게
/// 광고가 계속 보였다. "광고 제거"는 구독 화면이 약속한 유료 혜택이라
/// 결제 직후 첫인상이 곧 환불 문의 사유가 된다. 표시 지점에서
/// PurchaseService 를 구독해 프리미엄이 되는 순간 사라지게 한다.
///
/// 세 화면(퀴즈·AI 모의고사·기출)에 같은 코드가 복붙되어 있던 것의 정본이다.
class BannerAdBar extends StatelessWidget {
  final BannerAd? bannerAd;
  final bool loaded;

  /// 테스트에서 AdWidget 을 대체하기 위한 시임. AdWidget 은 load() 되지 않은
  /// 광고를 트리에 넣으면 예외를 던져 위젯 테스트에서는 그릴 수 없다.
  @visibleForTesting
  final Widget Function(BannerAd ad)? adWidgetBuilder;

  const BannerAdBar({
    super.key,
    required this.bannerAd,
    required this.loaded,
    this.adWidgetBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // isPremium 만 구독한다. watch 로 서비스 전체를 구독하면 상품 목록 로드나
    // 결제 에러 같은 무관한 알림에도 세 화면의 배너 자리가 다시 그려진다.
    final isPremium =
        context.select<PurchaseService, bool>((s) => s.isPremium);
    final ad = bannerAd;
    if (isPremium || !loaded || ad == null) {
      // 이 위젯은 항상 bottomNavigationBar 자리에 있다. Scaffold 는 그 자리가
      // 비어 있지 않으면 body 의 하단 안전영역 패딩을 걷어내므로, 배너를 숨길
      // 때도 홈 인디케이터만큼은 여기서 차지해야 한다. 그냥 shrink 만 돌려주면
      // 화면 하단 버튼이 홈 인디케이터 밑에 깔린다 — 방금 결제한 프리미엄
      // 유저가 제일 먼저 겪는다.
      return const SafeArea(child: SizedBox.shrink());
    }
    return SafeArea(
      child: SizedBox(
        height: ad.size.height.toDouble(),
        width: ad.size.width.toDouble(),
        child: adWidgetBuilder?.call(ad) ?? AdWidget(ad: ad),
      ),
    );
  }
}
