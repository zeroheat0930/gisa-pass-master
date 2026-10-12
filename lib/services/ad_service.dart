import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 리워드 광고 한 번의 결말. 유저에게 줄 안내가 셋 다 다르다.
enum RewardedAdResult {
  /// 광고가 뜨지 못했다(미로드·표시 실패·show 예외·타임아웃). 유저 잘못이 아니다.
  failedToShow,

  /// 광고는 떴지만 보상 조건 전에 닫았다.
  dismissedEarly,

  /// 끝까지 봐서 보상 조건을 채웠다. 이때만 보상한다.
  earned,
}

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

  // 리워드 광고 ID (실 단위, 2026-08-12 교체).
  // v1.6.4 까지는 Google 테스트 ID 였고 그동안 리워드 노출 수익이 0 이었다.
  // 되돌리면 수익이 다시 0 이 되므로 ad_id_test.dart 가 테스트 ID 복귀를 막는다.
  static const String _androidRewardedId =
      'ca-app-pub-5911237489066113/4234668134';
  static const String _iosRewardedId = 'ca-app-pub-5911237489066113/4862826277';

  /// Google 공식 테스트 계정의 퍼블리셔 번호. 이걸로 시작하는 단위는 수익이 0 이다.
  static const String testPublisherPrefix = 'ca-app-pub-3940256099942544';

  /// 리워드 광고 ID 가 아직 테스트 ID 인지. 설정 화면 등에서 안내에 쓸 수 있다.
  /// **두 플랫폼을 모두** 본다 — Android 만 검사하면 Android ID 만 실 ID 로
  /// 바꾼 뒤 iOS 가 테스트 ID 로 남아 있어도 '실 ID 사용 중'이라고 거짓 보고한다.
  static bool get isRewardedUsingTestId =>
      _androidRewardedId.startsWith(testPublisherPrefix) ||
      _iosRewardedId.startsWith(testPublisherPrefix);

  /// 검증용 — 테스트에서 전 광고 단위를 훑어보기 위해 노출한다.
  @visibleForTesting
  static const Map<String, String> allAdUnitIds = {
    'android/interstitial': _androidInterstitialId,
    'ios/interstitial': _iosInterstitialId,
    'android/banner': _androidBannerId,
    'ios/banner': _iosBannerId,
    'android/rewarded': _androidRewardedId,
    'ios/rewarded': _iosRewardedId,
  };

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

  /// 전면광고 표시 (프리미엄이면 표시 안 함).
  ///
  /// 실제로 광고가 떴으면 true. 호출부가 광고 위에 다른 팝업(OS 리뷰 요청 등)을
  /// 겹쳐 올리지 않도록 판단하는 데 쓴다. 준비가 안 돼 로드만 걸었으면 false.
  bool showInterstitialAd() {
    try {
      if (!shouldShowAds) return false;
      if (_isAdLoaded && _interstitialAd != null) {
        _interstitialAd!.show();
        return true;
      } else {
        loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('광고 표시 실패: $e');
    }
    return false;
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

  /// 리워드 광고 보상 판정을 기다리는 유예 시간.
  /// 닫힘 콜백이 보상 콜백보다 먼저 오는 어댑터(미디에이션)가 있어, 닫히자마자
  /// 판정하면 끝까지 본 유저의 보상이 사라진다. 그 순서 차이를 흡수할 만큼만 기다린다.
  @visibleForTesting
  static const Duration rewardGracePeriod = Duration(milliseconds: 500);

  /// 리워드 광고를 보여주고 결과를 [RewardedAdResult] 로 돌려준다.
  ///
  /// 실패([RewardedAdResult.failedToShow])와 중간 이탈
  /// ([RewardedAdResult.dismissedEarly])을 구분하는 이유: 예전엔 둘 다 false 라,
  /// 광고가 아예 뜨지도 못했는데 "끝까지 보셔야 지급돼요" 라고 유저 탓을 했다.
  /// 보상은 [RewardedAdResult.earned] 일 때만 준다.
  Future<RewardedAdResult> showRewardedAd() async {
    if (!shouldShowAds) return RewardedAdResult.failedToShow;
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      return RewardedAdResult.failedToShow;
    }

    _rewardedAd = null; // 1회용
    var shown = false;
    final settler = RewardedAdSettler(gracePeriod: rewardGracePeriod);
    // 콜백이 아예 오지 않는 비정상 경로의 안전판. 이게 없으면 호출자
    // (모의고사 버튼의 _isNavigating 등)가 앱 재시작 전까지 잠긴다.
    //
    // 단, 광고가 **화면에 뜬 뒤**에는 이 안전판을 걷는다. 시청 중 전화가 오거나
    // 앱이 오래 백그라운드에 갔다 오면 Dart 타이머는 복귀 즉시 발화하는데,
    // 그때 실패로 먼저 끝내버리면 유저가 끝까지 본 광고의 보상이 사라진다
    // (닫힘 콜백이 completer 를 채워도 듣는 쪽이 없다). 화면에 뜬 광고는
    // 닫힐 때 반드시 onAdDismissed 가 오므로 그쪽에 맡긴다.
    final guard = Timer(const Duration(minutes: 3), () {
      if (shown || settler.isSettled) return;
      debugPrint('리워드 광고가 3분 안에 뜨지 않음 — 호출자를 풀어준다');
      ad.dispose(); // 다른 종료 경로처럼 뜨지 못한 광고를 해제한다
      loadRewardedAd();
      settler.fail();
    });

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => shown = true,
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd(); // 다음 기회를 위해 미리 채워둔다
        settler.dismiss();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('리워드 광고 표시 실패: ${error.message}');
        ad.dispose();
        loadRewardedAd();
        settler.fail();
      },
    );

    try {
      await ad.show(onUserEarnedReward: (_, __) => settler.reward());
    } catch (e) {
      debugPrint('리워드 광고 show 오류: $e');
      ad.dispose();
      loadRewardedAd(); // 정상 경로의 콜백들처럼 다음 노출 기회를 채워둔다
      settler.fail();
    }
    final result = await settler.result;
    guard.cancel();
    return result;
  }

  /// 리소스 해제.
  ///
  /// 앱에서는 부르는 곳이 없다 — main.dart 가 앱 수명 동안 하나만 만들어 쓰는
  /// 싱글턴이라 해제 시점이 프로세스 종료뿐이다. 테스트나 핫 리스타트처럼
  /// 서비스를 갈아끼울 때를 위한 것이지, 누수 방지 장치로 믿으면 안 된다.
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isLoadingRewarded = false;
  }
}

/// 리워드 광고 콜백들을 모아 **한 번만** 결론을 내는 판정기.
///
/// 보상 판정은 **보상 콜백과 닫힘 콜백이 둘 다 정해졌을 때** 내린다. 예전에는
/// onUserEarnedReward 가 닫힘보다 먼저 온다고 가정하고 닫히는 순간 판정했는데,
/// 미디에이션 어댑터에 따라 순서가 뒤집히면 끝까지 본 유저의 보상이 사라진다.
/// 닫혔는데 보상이 아직이면 [gracePeriod] 만큼 더 기다린 뒤에야 이탈로 본다.
///
/// 광고 SDK 객체 없이 순서만 검증할 수 있게 [AdService] 밖으로 뺐다.
@visibleForTesting
class RewardedAdSettler {
  RewardedAdSettler({required this.gracePeriod});

  final Duration gracePeriod;
  final Completer<RewardedAdResult> _completer = Completer<RewardedAdResult>();
  bool _earned = false;
  bool _dismissed = false;
  Timer? _grace;

  Future<RewardedAdResult> get result => _completer.future;
  bool get isSettled => _completer.isCompleted;

  /// onUserEarnedReward. 닫힘이 먼저 와서 유예 중이면 여기서 바로 결론낸다.
  void reward() {
    _earned = true;
    _settleIfDismissed();
  }

  /// onAdDismissedFullScreenContent
  void dismiss() {
    _dismissed = true;
    _settleIfDismissed();
  }

  /// 표시 실패·show 예외·타임아웃. 유저 잘못이 아니다.
  void fail() => _finish(RewardedAdResult.failedToShow);

  void _settleIfDismissed() {
    if (!_dismissed) return;
    if (_earned) {
      _finish(RewardedAdResult.earned);
      return;
    }
    _grace ??= Timer(gracePeriod, () {
      _finish(
        _earned ? RewardedAdResult.earned : RewardedAdResult.dismissedEarly,
      );
    });
  }

  // 모든 종료 경로가 여기로 모인다. 두 번 불려도 처음 결과만 남는다.
  void _finish(RewardedAdResult result) {
    _grace?.cancel();
    if (!_completer.isCompleted) _completer.complete(result);
  }
}
