import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

AdService? _globalAdService;
void setGlobalAdService(AdService s) => _globalAdService = s;
AdService? get globalAdService => _globalAdService;

/// AdMob 광고 서비스
class AdService {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoadingInterstitial = false;
  bool _isPremium = false;

  // AdMob 실제 광고 ID
  static const String _androidInterstitialId = 'ca-app-pub-5911237489066113/6189482948';
  static const String _iosInterstitialId = 'ca-app-pub-5911237489066113/1152778683';
  static const String _androidBannerId = 'ca-app-pub-5911237489066113/3631497162';
  static const String _iosBannerId = 'ca-app-pub-5911237489066113/2286625905';

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidInterstitialId;
      case TargetPlatform.iOS:
        return _iosInterstitialId;
      default:
        return '';
    }
  }

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidBannerId;
      case TargetPlatform.iOS:
        return _iosBannerId;
      default:
        return '';
    }
  }

  bool get isAdLoaded => _isAdLoaded;
  bool get isPremium => _isPremium;

  // 광고 활성화 (true = 광고 표시, false = 비활성화)
  static const bool adsEnabled = true;

  /// 프리미엄 사용자 설정 (광고 숨김)
  void setPremium(bool value) {
    _isPremium = value;
    if (_isPremium) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isAdLoaded = false;
      _isLoadingInterstitial = false;
    }
  }

  /// 광고를 보여야 하는지 여부
  bool get shouldShowAds => adsEnabled && !_isPremium && !kIsWeb;

  /// 광고 SDK 초기화
  static Future<void> initialize() async {
    if (!adsEnabled || kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
    }
  }

  /// 전면광고 미리 로드
  ///
  /// 동시 로드를 막는다. showInterstitialAd() 는 광고가 준비되지 않았으면
  /// 매번 이 함수를 부르는데(3문제마다), 가드가 없으면 로드가 여러 개 겹쳐서
  /// 나중에 성공한 광고가 앞의 광고를 dispose 없이 덮어쓴다.
  /// 네이티브 객체 누수 + AdMob fill 낭비로 이어진다.
  void loadInterstitialAd() {
    try {
      if (!shouldShowAds) return;
      if (_isLoadingInterstitial || _isAdLoaded) return;
      final adUnitId = interstitialAdUnitId;
      if (adUnitId.isEmpty) return;

      _isLoadingInterstitial = true;
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingInterstitial = false;
            // 혹시 남아있는 이전 광고가 있으면 반드시 정리하고 교체한다.
            _interstitialAd?.dispose();
            _interstitialAd = ad;
            _isAdLoaded = true;
            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _isAdLoaded = false;
                _interstitialAd = null;
                loadInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _isAdLoaded = false;
                _interstitialAd = null;
                loadInterstitialAd();
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('전면광고 로드 실패: ${error.message}');
            _isLoadingInterstitial = false;
            // 이미 로드해둔 광고가 있으면 건드리지 않는다.
            // 예전에는 무조건 false 로 덮어써서, 준비된 광고가 멀쩡히 있는데도
            // 사용 불가 상태가 되어 전면광고가 영영 표시되지 않았다(수익 중단).
            _isAdLoaded = _interstitialAd != null;
          },
        ),
      );
    } catch (e) {
      debugPrint('전면광고 로드 중 오류: $e');
      _isAdLoaded = false;
    }
  }

  /// 전면광고 표시 (프리미엄이면 표시 안 함)
  void showInterstitialAd() {
    try {
      if (!shouldShowAds) return;
      if (_isAdLoaded && _interstitialAd != null) {
        _interstitialAd!.show();
      } else {
        loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('광고 표시 실패: $e');
    }
  }

  /// 배너광고 생성 (shouldShowAds=false면 null 반환)
  BannerAd? createBannerAd({VoidCallback? onLoad, VoidCallback? onError}) {
    if (!shouldShowAds) return null;
    final adUnitId = bannerAdUnitId;
    if (adUnitId.isEmpty) return null;
    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoad?.call(),
        onAdFailedToLoad: (ad, err) {
          debugPrint('배너광고 로드 실패: ${err.message}');
          ad.dispose();
          onError?.call();
        },
      ),
    )..load();
  }

  /// 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
