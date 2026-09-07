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

  const BannerAdBar({super.key, required this.bannerAd, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PurchaseService>().isPremium;
    final ad = bannerAd;
    if (isPremium || !loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      child: SizedBox(
        height: ad.size.height.toDouble(),
        width: ad.size.width.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
