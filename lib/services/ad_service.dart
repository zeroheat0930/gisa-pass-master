import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 전면광고 서비스
class AdService {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // 테스트 광고 ID (Google 공식 테스트 ID)
  static String get interstitialAdUnitId {
    if (kIsWeb) return ''; // 웹은 광고 미지원
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android 테스트
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS 테스트
    }
    return '';
  }

  bool get isAdLoaded => _isAdLoaded;

  // === 오픈 이벤트: 광고 비활성화 (출시 후 활성화) ===
  static const bool _adsEnabled = false;

  /// 광고 SDK 초기화
  static Future<void> initialize() async {
    if (!_adsEnabled || kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  /// 전면광고 미리 로드
  void loadInterstitialAd() {
    if (!_adsEnabled || kIsWeb) return;
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
              loadInterstitialAd(); // 다음 광고 미리 로드
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
  }

  /// 전면광고 표시 (로드된 경우에만)
  void showInterstitialAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      loadInterstitialAd(); // 로드 안 됐으면 다시 시도
    }
  }

  /// 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
