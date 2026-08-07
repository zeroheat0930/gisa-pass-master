import 'dart:async';

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

  // ⚠️ 리워드 광고 ID — 현재 Google 공식 **테스트 ID** 다.
  // AdMob 콘솔에서 리워드 광고 단위를 Android/iOS 각각 만들고 이 두 줄만 바꾸면
  // 실제 수익이 잡힌다. 테스트 ID 그대로 배포해도 앱은 정상 동작하지만
  // 수익은 0 이다. (실 ID 로 바꾸기 전까지 이 주석을 지우지 말 것)
  static const String _androidRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  /// 리워드 광고 ID 가 아직 테스트 ID 인지. 설정 화면 등에서 안내에 쓸 수 있다.
  static bool get isRewardedUsingTestId =>
      _androidRewardedId.startsWith('ca-app-pub-3940256099942544');

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

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidRewardedId;
      case TargetPlatform.iOS:
        return _iosRewardedId;
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
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isLoadingRewarded = false;
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
      // 로딩 플래그를 반드시 내린다. 여기서 빠뜨리면 loadInterstitialAd 의
      // 중복 로드 가드에 영구히 걸려 전면광고가 세션 내내 다시 로드되지 않는다
      // (= 전면광고 수익 중단이 다른 형태로 재발한다).
      _isLoadingInterstitial = false;
      _isAdLoaded = _interstitialAd != null;
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
  ///
  /// [onRetry] 가 주어지면 로드 실패 시 잠시 뒤 새 배너를 만들어 넘겨준다.
  /// 재시도가 없으면 일시적인 네트워크 오류 한 번으로 그 화면 세션의 배너 수익이
  /// 통째로 0이 된다.
  BannerAd? createBannerAd({
    VoidCallback? onLoad,
    VoidCallback? onError,
    void Function(BannerAd ad)? onRetry,
    int attempt = 0,
  }) {
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
          debugPrint('배너광고 로드 실패(시도 ${attempt + 1}): ${err.message}');
          ad.dispose();
          onError?.call();

          // 지수 백오프로 최대 3회까지 재시도한다.
          if (onRetry != null && attempt < 2) {
            final delay = Duration(seconds: 4 * (attempt + 1));
            Future.delayed(delay, () {
              final next = createBannerAd(
                onLoad: onLoad,
                onError: onError,
                onRetry: onRetry,
                attempt: attempt + 1,
              );
              if (next != null) onRetry(next);
            });
          }
        },
      ),
    )..load();
  }

  // ── 리워드 광고 ──────────────────────────────────────────────────────────
  // 무료 유저가 광고를 보고 잠긴 기능을 1회 열 수 있게 한다.
  // 새 수익원이면서, 프리미엄을 체험시켜 구매로 이어지는 통로이기도 하다.

  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  bool get isRewardedReady => _rewardedAd != null;

  /// 리워드 광고 미리 로드. 프리미엄 유저에게는 필요 없다.
  void loadRewardedAd() {
    try {
      if (!shouldShowAds) return;
      if (_isLoadingRewarded || _rewardedAd != null) return;
      final adUnitId = rewardedAdUnitId;
      if (adUnitId.isEmpty) return;

      _isLoadingRewarded = true;
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingRewarded = false;
            _rewardedAd?.dispose();
            _rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            debugPrint('리워드 광고 로드 실패: ${error.message}');
            _isLoadingRewarded = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('리워드 광고 로드 중 오류: $e');
      _isLoadingRewarded = false;
    }
  }

  /// 리워드 광고를 보여주고 **끝까지 봤는지** 반환한다.
  /// 중간에 닫으면 false — 보상을 주면 안 된다.
  Future<bool> showRewardedAd() async {
    if (!shouldShowAds) return false;
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      return false;
    }

    _rewardedAd = null; // 1회용
    var earned = false;

    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd(); // 다음 기회를 위해 미리 채워둔다
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('리워드 광고 표시 실패: ${error.message}');
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (e) {
      debugPrint('리워드 광고 show 오류: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  /// 리소스 해제
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
