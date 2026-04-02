import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 광고 서비스
class AdService {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
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
  void loadInterstitialAd() {
    try {
      if (!shouldShowAds) return;
      final adUnitId = interstitialAdUnitId;
      if (adUnitId.isEmpty) return;

      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
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
            _isAdLoaded = false;
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

  /// 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
