import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// 화면 하나가 가진 배너의 생명주기 정본 — 로드, 실패 시 재시도 배너로 교체, 해제.
///
/// [BannerAdBar] 가 표시 쪽을 통합한 뒤에도 로드·재시도·dispose 블록은 세 화면
/// (퀴즈·AI 모의고사·기출)에 그대로 복붙되어 있었다. 한쪽만 고치면 나머지가
/// 어긋나는 패턴이라 여기로 모은다. 화면은 이것을 listen 해 다시 그리기만 한다.
///
/// 사용: State 의 initState 에서 `_banner = BannerAdHost()..addListener(...)..load()`,
/// dispose 에서 `_banner.dispose()`, build 에서
/// `BannerAdBar(bannerAd: _banner.ad, loaded: _banner.loaded)`.
class BannerAdHost extends ChangeNotifier {
  BannerAd? _ad;
  bool _loaded = false;
  bool _disposed = false;

  /// 현재 배너. 광고를 안 보여주는 유저(프리미엄 등)나 로드 전이면 null.
  BannerAd? get ad => _ad;

  /// 현재 배너가 로드를 마쳤는지
  bool get loaded => _loaded;

  /// 배너 로드를 시작한다. 로드가 실패해도 재시도한 배너로 교체한다 — 재시도가
  /// 없으면 일시적인 네트워크 오류 한 번으로 이 화면 세션의 배너 수익이 0이 된다.
  void load() {
    _ad = globalAdService?.createBannerAd(
      onLoad: () => _setLoaded(true),
      onError: () => _setLoaded(false),
      onRetry: (next) {
        // 화면이 이미 내려간 뒤 도착한 재시도 배너는 붙일 곳이 없다.
        if (_disposed) {
          next.dispose();
          return;
        }
        _ad?.dispose();
        _ad = next;
        notifyListeners();
      },
    );
  }

  void _setLoaded(bool value) {
    if (_disposed) return;
    _loaded = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}
