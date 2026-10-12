import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';

class PurchaseService extends ChangeNotifier {
  // 1회성 비소모성 상품 (평생 이용) — ID 의 `_monthly` 는 초기 명명 잔재로, 구독이 아님
  static const String premiumMonthlyId = 'gisa_pass_premium_monthly';

  /// 구매 완료 사실을 기기에 영속 저장하는 키.
  /// 스토어는 이미 완료(completePurchase)된 트랜잭션을 앱 재시작 시 스트림으로
  /// 다시 보내주지 않으므로, 이 캐시가 없으면 결제한 유저가 앱을 껐다 켤 때마다
  /// 프리미엄을 잃는다.
  static const String _prefsKeyPremium = 'premium_purchased';

  /// 설치 후 자동 복원을 이미 시도했는지 여부 (설치당 1회로 제한).
  static const String _prefsKeyAutoRestored = 'premium_auto_restore_done';

  /// 자동 복원 시도 횟수. 성공해야만 완료 플래그가 서므로, iOS App Store
  /// 미로그인 유저가 로그인 팝업을 취소하면(예외) 매 실행 팝업이 반복된다.
  /// SDK 가 '유저 취소'와 '네트워크 실패'를 구분해주지 않아 횟수 상한으로 막는다.
  static const String _prefsKeyAutoRestoreAttempts =
      'premium_auto_restore_attempts';
  static const int _maxAutoRestoreAttempts = 3;

  /// 이 구매가 어느 기기에서 이뤄졌는지. 백업 복제 감지용.
  static const String _prefsKeyPremiumOwner = 'premium_owner_device';

  /// Android 시작 복원이 '프리미엄 없음'을 연속으로 돌려준 횟수.
  /// 한 번의 빈 결과로 회수하지 않는다 — Play 스토어 계정 전환 직후·캐시 동기화
  /// 중 같은 일시 상태에서도 빈 목록이 OK 로 올 수 있고, 정상 구매자를 무료로
  /// 강등하는 것이 환불자를 하루 더 봐주는 것보다 훨씬 해롭다.
  static const String _prefsKeyEmptyRestoreStrikes =
      'premium_empty_restore_strikes';
  static const int _revokeAfterEmptyRestores = 2;

  /// 프리미엄을 회수했음을 다음 구독 화면 진입 때 알리기 위한 표시.
  static const String _prefsKeyRevokedNotice = 'premium_revoked_notice';

  // 관리자 기기: 자동 프리미엄 (결제 불필요)
  static const Set<String> _adminDeviceIds = {
    '91ED9D8E-7430-4194-B9D0-D0099A772E02', // 정동준의 iPhone
  };

  /// 지연 평가한다. 필드 초기화로 두면 PurchaseService 를 만드는 것만으로
  /// 스토어 연결이 시작되어, 스토어를 쓰지 않는 경로(로컬 캐시 복원 등)와
  /// 테스트 환경에서 플랫폼 예외가 튄다.
  InAppPurchase get _iap => InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  AdService? _adService;

  bool _available = false;
  bool _isPremium = false;
  List<ProductDetails> _products = [];
  bool _loading = false;
  String? _error;

  bool get isPremium => _isPremium;
  bool get available => _available;
  List<ProductDetails> get products => _products;
  bool get loading => _loading;
  String? get error => _error;

  /// 결제·복원 흐름에서 유저에게 보여줘야 할 에러가 새로 생길 때마다 1씩 오른다.
  ///
  /// 스토어 결과는 buyPremium 이 끝난 **뒤에** 스트림으로 온다. 화면이 error
  /// 문자열만 비교하면 같은 실패가 두 번 연속 나도 두 번째를 못 알아채고,
  /// 시작 시의 '스토어 초기화 실패' 같은 배경 에러까지 스낵바로 튀어나온다.
  /// 그래서 '보여줄 새 에러가 생겼다'는 사건을 따로 센다.
  int _purchaseErrorSerial = 0;
  int get purchaseErrorSerial => _purchaseErrorSerial;

  void _setPurchaseError(String message) {
    _error = message;
    _purchaseErrorSerial++;
    notifyListeners();
  }

  /// 결제가 스토어에서 승인 대기 중인지 (가족 승인, 편의점·현금 지연 결제).
  /// 이 상태를 모르면 유저는 결제가 씹힌 줄 알고 다시 누르거나 문의한다.
  bool _pendingApproval = false;
  bool get isPendingApproval => _pendingApproval;

  void _setPendingApproval(bool value) {
    if (_pendingApproval == value) return;
    _pendingApproval = value;
    notifyListeners();
  }

  /// 스토어에서 구매가 확인되지 않아 프리미엄을 회수했는지. 구독 화면이 한 번
  /// '구매 복원' 안내를 띄우는 데 쓴다.
  bool _premiumRevoked = false;
  bool get premiumRevoked => _premiumRevoked;

  /// 구독 화면이 회수 안내를 보여줬으면 부른다. 화면에 떠 있는 동안은 그대로
  /// 보이고, 다음 진입부터는 안 보인다 — 일부러 환불한 유저에게 매번 띄울
  /// 이유는 없다.
  Future<void> acknowledgeRevokedNotice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyRevokedNotice);
    } catch (e) {
      debugPrint('회수 안내 플래그 제거 실패: $e');
    }
  }

  void setAdService(AdService adService) {
    _adService = adService;
  }

  /// 기기에 저장된 구매 이력만 복원한다. 네트워크를 타지 않는다.
  ///
  /// **첫 프레임 전에 이것만 호출할 것.** 여기서 광고를 즉시 끄지 않으면
  /// 결제 유저에게 첫 화면 광고가 새어나간다. 스토어 연결(initialize)은
  /// 네트워크 왕복이라 첫 프레임을 인질로 잡으면 안 된다.
  Future<void> restoreCachedPremium() async {
    if (kIsWeb || _cacheRestored) return;
    _cacheRestored = true;
    await _loadCachedPremium();
  }

  bool _cacheRestored = false;

  /// purchaseStream 구독만 건다. 네트워크·스토어 왕복 없음, 여러 번 불러도 한 번만 건다.
  ///
  /// main 이 runApp 직후에 부른다. initialize 는 AdMob 초기화·ATT 뒤에야 돌아서
  /// 그 사이(수 초)에 유저가 결제하면, Android 는 그 결과 이벤트를 받을 리스너가
  /// 없어 유실된다(브로드캐스트 스트림은 늦게 온 구독자에게 재전달하지 않는다).
  /// 그러면 돈은 나갔는데 프리미엄이 안 켜지고, acknowledge 도 못 해 3일 뒤 자동 환불된다.
  void listenToPurchaseStream() {
    if (kIsWeb || _subscription != null) return;
    try {
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('구매 에러: $error'),
      );
    } catch (e) {
      // 스토어 플러그인이 없는 환경(테스트 등). initialize 에서 다시 시도된다.
      debugPrint('purchaseStream 구독 실패: $e');
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    // 저장된 구매 이력 복원 — 스토어 통신보다 먼저, 오프라인에서도 동작해야 한다.
    // (main 이 첫 프레임 전에 이미 호출했으면 그대로 통과한다)
    await restoreCachedPremium();

    // purchaseStream 구독은 스토어 가용성과 무관하게 **가장 먼저** 건다.
    // 예전에는 isAvailable() 이 false 면 여기까지 오지 못하고 return 해서 구독이
    // 영영 생성되지 않았다. 그 세션에서는 결제를 완료해도 콜백이 오지 않아
    // 프리미엄이 켜지지 않았다(결제만 되고 물건은 안 나오는 상태).
    // 관리자 기기 분기보다도 먼저다 — 분기 뒤에 두면 관리자 기기에서
    // 결제 콜백이 영영 오지 않아 그 기기에서의 결제 QA 가 무의미해진다.
    // (보통은 main 이 runApp 직후 이미 걸어둬서 여기선 통과한다)
    listenToPurchaseStream();

    // 관리자 기기 체크 (iOS 만 해당 — Android 는 AD_ID 권한 정책상 식별자 제한)
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        final deviceId = iosInfo.identifierForVendor ?? '';
        if (_adminDeviceIds.contains(deviceId)) {
          _isPremium = true;
          _adService?.setPremium(true);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('기기 정보 확인 실패: $e');
    }

    try {
      _available = await _iap.isAvailable();
      debugPrint('IAP available: $_available');
      if (!_available) {
        _error = '스토어를 사용할 수 없습니다';
        notifyListeners();
        return;
      }

      await _loadProducts();

      // Android 는 **매 실행** 복원(queryPurchases)을 돈다.
      // StoreKit 과 달리 Android 결제 플러그인은 미종결(acknowledge 안 된)
      // 구매를 다음 실행에 purchaseStream 으로 재전달해 주지 않는다. 이 재조회가
      // 없으면 저장 실패나 프로세스 종료로 acknowledge 를 놓친 구매가 재시도될
      // 길이 없고, Google Play 는 3일 내 미확인 구매를 자동 환불해 버린다.
      // (편의점 결제 등 pending 이 앱 종료 후 승인되는 경우도 이 경로로만 수신된다)
      // Android 의 queryPurchases 는 iOS 와 달리 로그인 팝업을 띄우지 않으므로
      // 매 실행 돌려도 유저에게 보이는 부작용이 없다.
      //
      // 환불·취소 회수도 이 복원 결과로 한다(Android 만). iOS 는 매 실행
      // restoreCompletedTransactions 를 돌리면 App Store 로그인 팝업이 뜰 수 있어
      // 회수 근거를 얻을 방법이 없다. 영수증 서버 검증(또는 StoreKit 2 의
      // Transaction.currentEntitlements) 없이는 iOS 환불 회수는 불가 — 추후 과제.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await runAndroidStartupRestore();
      } else {
        await _autoRestoreOnce();
      }
    } catch (e) {
      debugPrint('IAP 초기화 실패: $e');
      _error = '스토어 초기화 실패';
      notifyListeners();
    }
  }

  /// Android 시작 시 복원 — 미종결 구매 재수신 + 환불·취소 회수 판정.
  ///
  /// 플러그인(in_app_purchase_android 0.5.2)의 restorePurchases 는 조회가
  /// 성공하면 **빈 목록이어도** purchaseStream 에 add 하고, 조회가 하나라도
  /// 실패하면 add 하기 **전에** 예외를 던진다. 그래서 '요청했고 예외 없이
  /// 끝났다' + '그 뒤 처음 오는 전부-restored 이벤트' = 스토어가 확인해 준
  /// 이 계정의 구매 전체 목록(스냅샷)이다. 예외면 스냅샷 대기를 거두므로
  /// 오프라인·스토어 장애로는 절대 회수되지 않는다.
  ///
  /// 이벤트 도착과 이 Future 완료의 순서는 보장되지 않으므로(둘 다 마이크로태스크)
  /// 판정은 스트림 핸들러 쪽에서 한다.
  @visibleForTesting
  Future<void> runAndroidStartupRestore() async {
    _awaitingRestoreSnapshot = true;
    _grantedSinceSnapshotRequest = false;
    try {
      await _storeRestore();
    } catch (e) {
      _awaitingRestoreSnapshot = false;
      rethrow;
    }
  }

  /// 복원 결과(스냅샷)를 기다리는 중인지. Android 시작 복원에서만 선다.
  bool _awaitingRestoreSnapshot = false;

  /// 스냅샷 요청 이후 이 세션에서 프리미엄을 지급했는지. 요청 직후 유저가
  /// 결제를 끝내면, 결제 전에 조회된 빈 스냅샷이 결제 이벤트보다 늦게 도착할
  /// 수 있다 — 그걸 믿고 회수하면 방금 돈 낸 유저를 강등한다.
  bool _grantedSinceSnapshotRequest = false;

  /// 테스트에서 스토어 복원 호출을 가로채기 위한 시임.
  @visibleForTesting
  Future<void> Function()? restorePurchasesForTest;

  Future<void> _storeRestore() {
    final override = restorePurchasesForTest;
    if (override != null) return override();
    return _iap.restorePurchases();
  }

  /// 테스트에서 스토어 가용 판정을 고정한다 (테스트 환경엔 플랫폼 구현이 없다).
  @visibleForTesting
  void debugSetAvailable(bool value) => _available = value;

  /// 스냅샷에 지급 가능한 프리미엄 구매가 없을 때. 보수적으로만 회수한다.
  Future<void> _onEmptyRestoreSnapshot() async {
    if (!_isPremium) return; // 회수할 것이 없다
    // 이 세션에서 막 지급됐거나 결제가 진행 중이면 스냅샷이 낡았을 수 있다.
    if (_grantedSinceSnapshotRequest || _buyInFlight) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final strikes = (prefs.getInt(_prefsKeyEmptyRestoreStrikes) ?? 0) + 1;
      if (strikes < _revokeAfterEmptyRestores) {
        await prefs.setInt(_prefsKeyEmptyRestoreStrikes, strikes);
        debugPrint('복원 결과에 프리미엄 없음 ($strikes회째) — 아직 유지');
        return;
      }
      // 판정 중 비동기 사이에 지급됐으면 회수하지 않는다.
      if (_grantedSinceSnapshotRequest) return;
      await prefs.remove(_prefsKeyPremium);
      await prefs.remove(_prefsKeyPremiumOwner);
      await prefs.remove(_prefsKeyEmptyRestoreStrikes);
      await prefs.setBool(_prefsKeyRevokedNotice, true);
    } catch (e) {
      // 저장소를 못 건드리면 회수하지 않는다 — 캐시와 화면이 어긋나면
      // 다음 실행에 다시 켜졌다 꺼졌다 한다.
      debugPrint('프리미엄 회수 실패 — 유지: $e');
      return;
    }
    debugPrint('스토어에 구매가 없어 프리미엄 회수 (환불·취소)');
    _isPremium = false;
    _premiumRevoked = true;
    _adService?.setPremium(false);
    notifyListeners();
  }

  /// 스냅샷에 프리미엄이 있으면 연속 빈 결과 횟수를 리셋한다.
  Future<void> _resetEmptyRestoreStrikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyEmptyRestoreStrikes);
    } catch (_) {}
  }

  /// 설치 후 한 번만 자동으로 구매를 복원한다.
  ///
  /// 평생 이용권이라 재설치·기기변경 시에도 되살아나야 하는데, 로컬 캐시는
  /// 재설치로 사라진다. 그렇다고 매 실행마다 복원을 걸면 iOS 에서
  /// restoreCompletedTransactions 가 App Store 로그인 팝업을 띄울 수 있어
  /// 무료 유저까지 매번 팝업을 맞는다. 그래서 설치당 1회로 제한한다.
  /// (그 이후엔 구독 화면의 '구매 복원' 버튼이 담당한다.)
  Future<void> _autoRestoreOnce() async {
    if (_isPremium) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsKeyAutoRestored) ?? false) return;

      // 실패가 반복되면 포기한다. iOS 미로그인 유저가 로그인 팝업을 취소하면
      // 예외로 떨어져 완료 플래그가 서지 않는데, 상한이 없으면 그 유저는
      // 매 실행 팝업을 맞는다. 이후엔 구독 화면의 '구매 복원' 버튼이 담당한다.
      final attempts = prefs.getInt(_prefsKeyAutoRestoreAttempts) ?? 0;
      if (attempts >= _maxAutoRestoreAttempts) {
        await prefs.setBool(_prefsKeyAutoRestored, true);
        return;
      }
      await prefs.setInt(_prefsKeyAutoRestoreAttempts, attempts + 1);

      // 복원을 **성공한 뒤에** 플래그를 쓴다.
      // 먼저 쓰면 오프라인·스토어 일시 장애 한 번으로 1회뿐인 자동 복원 티켓이
      // 헛되이 소진되어, 기기를 바꾼 결제 유저가 영영 자동 복원을 못 받는다.
      await _iap.restorePurchases();
      await prefs.setBool(_prefsKeyAutoRestored, true);
    } catch (e) {
      debugPrint('자동 복원 실패 (다음 실행에 다시 시도): $e');
    }
  }

  /// 기기에 저장된 구매 이력을 읽어 프리미엄을 즉시 복원한다.
  Future<void> _loadCachedPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 지난 실행에서 회수됐으면 구독 화면에서 '구매 복원' 안내를 띄운다.
      if (prefs.getBool(_prefsKeyRevokedNotice) ?? false) {
        _premiumRevoked = true;
        notifyListeners();
      }
      if (!(prefs.getBool(_prefsKeyPremium) ?? false)) return;

      // 이 기기에서 산 구매인지 확인한다.
      // SharedPreferences 는 iCloud/Google 백업과 기기 이전으로 그대로 복제되므로,
      // 플래그만 믿으면 결제하지 않은 기기에서도 프리미엄이 켜진다.
      // 기기 식별자가 다르면 캐시를 버리고 스토어 복원에 맡긴다.
      final owner = prefs.getString(_prefsKeyPremiumOwner);
      final current = await _deviceFingerprint();
      if (owner != null && current != null && owner != current) {
        debugPrint('다른 기기의 구매 캐시 — 무시하고 스토어 복원에 맡긴다');
        await prefs.remove(_prefsKeyPremium);
        await prefs.remove(_prefsKeyPremiumOwner);
        await prefs.remove(_prefsKeyAutoRestored); // 새 기기에서 자동 복원 허용
        await prefs.remove(_prefsKeyAutoRestoreAttempts);
        return;
      }

      _isPremium = true;
      _adService?.setPremium(true);
      notifyListeners();

      // owner 미기록 캐시(owner 개념 도입 전에 결제한 유저)는 여기서 백필한다.
      // 안 하면 그 유저들에게는 백업 복제 방어가 영구히 무력하다.
      if (owner == null && current != null) {
        await prefs.setString(_prefsKeyPremiumOwner, current);
      }
    } catch (e) {
      debugPrint('구매 이력 로드 실패: $e');
    }
  }

  /// 기기 식별자. 얻지 못하면 null (그때는 캐시를 그대로 신뢰한다 —
  /// 정당한 유저를 막는 쪽이 더 해롭다).
  ///
  /// Android 는 항상 null — 지문 검사를 하지 않는다.
  /// 예전에 쓰던 `androidInfo.id` 는 Build.ID 라서 OS 업데이트·보안패치마다
  /// 바뀌고(결제 유저가 오프라인이면 무료로 강등), 같은 펌웨어의 모든 기기에서
  /// 동일해 백업 복제 감지라는 본래 목적에도 무력했다. 안정적인 기기 식별자가
  /// 없는 플랫폼에서는 검사를 생략하는 쪽이 결제 유저에게 안전하다.
  Future<String?> _deviceFingerprint() async {
    if (kIsWeb) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return (await DeviceInfoPlugin().iosInfo).identifierForVendor;
      }
    } catch (e) {
      debugPrint('기기 식별자 조회 실패: $e');
    }
    return null;
  }

  /// 구매/복원 확정 시 프리미엄을 켜고 기기에 영속 저장한다.
  ///
  /// 테스트에서 직접 호출할 수 있어야 한다. purchaseStream 을 통하지 않으면
  /// '쓰기' 경로를 검증할 수 없어서, 저장 코드를 통째로 지워도 테스트가 통과해버린다.
  @visibleForTesting
  Future<void> grantPremium() async {
    _isPremium = true;
    _error = null;
    _pendingApproval = false;
    _premiumRevoked = false;
    _grantedSinceSnapshotRequest = true;
    _adService?.setPremium(true);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyRevokedNotice);
      await prefs.setBool(_prefsKeyPremium, true);
      final fingerprint = await _deviceFingerprint();
      if (fingerprint != null) {
        await prefs.setString(_prefsKeyPremiumOwner, fingerprint);
      }
      _lastSaveSucceeded = true;
    } catch (e) {
      debugPrint('구매 이력 저장 실패: $e');
      _lastSaveSucceeded = false;
    }
  }

  /// 직전 grantPremium 의 저장이 성공했는지. 저장이 실패했는데 스토어 트랜잭션을
  /// 종결해버리면 재시작 후 프리미엄이 사라지고 복구 경로도 사라진다.
  bool _lastSaveSucceeded = false;

  Future<void> _loadProducts() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails({premiumMonthlyId});
      debugPrint('상품 조회 결과: found=${response.productDetails.length}, notFound=${response.notFoundIDs}');

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('상품을 찾을 수 없음: ${response.notFoundIDs}');
        _error = '상품 정보를 불러올 수 없습니다';
      }
      if (response.error != null) {
        debugPrint('상품 조회 에러: ${response.error}');
        _error = '스토어 연결 오류';
      }
      _products = response.productDetails;
    } catch (e) {
      debugPrint('상품 로드 실패: $e');
      _error = '상품 정보 로드 실패';
    }

    _loading = false;
    notifyListeners();
  }

  /// 상품 재로딩
  Future<void> reloadProducts() async {
    if (!_available) {
      _available = await _iap.isAvailable();
      if (!_available) return;
    }
    await _loadProducts();
  }

  /// 결제 요청이 스토어로 나간 뒤 돌아오기 전인지. 연타 가드.
  ///
  /// iOS 는 같은 상품을 연달아 buyNonConsumable 하면 StoreKit 이
  /// storekit_duplicate_product_object 를 던져, 결제 시트가 떠 있는데
  /// "구매 처리 중 오류" 스낵바가 겹친다. 중복 결제는 아니지만 유저는 실패로 읽는다.
  bool _buyInFlight = false;
  bool get isBuying => _buyInFlight;

  Future<void> buyPremium() async {
    if (_buyInFlight) return;
    _buyInFlight = true;
    try {
      await _buyPremium();
    } finally {
      _buyInFlight = false;
    }
  }

  Future<void> _buyPremium() async {
    try {
      // 이전 시도의 실패 메시지를 지운다. 남겨두면 이번 결제가 정상 진행 중인데도
      // 화면이 옛 에러 스낵바를 띄운다.
      _error = null;

      // 상품이 없으면 재로딩 시도
      if (_products.isEmpty) {
        await reloadProducts();
      }

      if (!_available || _products.isEmpty) {
        _setPurchaseError('구매할 수 있는 상품이 없습니다. 잠시 후 다시 시도해주세요.');
        return;
      }

      final product = _products.first;

      debugPrint('구매 시작: ${product.id} - ${product.price}');
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('구매 실패: $e');
      _setPurchaseError('구매 처리 중 오류가 발생했습니다');
    }
  }

  /// 스토어에 구매 복원을 요청한다. 요청이 접수됐으면 true.
  ///
  /// buyPremium 처럼 스토어 가용성을 재확인한다 — 시작 시 1회 판정된
  /// `_available` 이 false 로 남아 있으면, 재설치 유저의 유일한 수동 복구
  /// 경로인 이 버튼이 아무 표시 없이 침묵으로 죽는다.
  Future<bool> restorePurchases() async {
    try {
      _error = null;
      if (!_available) {
        _available = await _iap.isAvailable();
        if (!_available) {
          _setPurchaseError('스토어에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
          return false;
        }
      }
      await _storeRestore();
      return true;
    } catch (e) {
      debugPrint('구매 복원 실패: $e');
      _setPurchaseError('구매 복원에 실패했습니다. 잠시 후 다시 시도해주세요.');
      return false;
    }
  }

  /// 프리미엄이 켜질 때까지 최대 [timeout] 기다린다. 켜지면 true.
  ///
  /// 복원 요청은 '접수'만 알려주고 결과는 스트림으로 늦게 온다. 기다리지 않고
  /// "곧 반영됩니다" 로 끝내면, 복원할 구매가 없는 유저(다른 계정 로그인 등)는
  /// 아무 일도 안 일어난 채 이유를 모른다.
  Future<bool> waitForPremium(Duration timeout) {
    if (_isPremium) return Future.value(true);
    final completer = Completer<bool>();
    late final VoidCallback listener;
    Timer? timer;
    void finish(bool value) {
      if (completer.isCompleted) return;
      timer?.cancel();
      removeListener(listener);
      completer.complete(value);
    }

    listener = () {
      if (_isPremium) finish(true);
    };
    addListener(listener);
    timer = Timer(timeout, () => finish(_isPremium));
    return completer.future;
  }

  /// purchaseStream 핸들러의 테스트 진입점.
  ///
  /// 실제 결제가 흐르는 경로는 이 핸들러 하나뿐인데 private 이라, 지금까지
  /// "purchased → grantPremium → (저장 성공 시에만) completePurchase" 계약을
  /// 통째로 되돌려도 모든 테스트가 통과했다. v1.5.4 '결제 소실'이 터졌던
  /// 바로 그 지점이다.
  @visibleForTesting
  void handlePurchaseUpdates(List<PurchaseDetails> purchases) =>
      _onPurchaseUpdate(purchases);

  /// 테스트에서 스토어 호출을 가로채기 위한 시임.
  /// 테스트 환경에는 IAP 플랫폼 구현이 없어 completePurchase 가 예외를 던진다.
  @visibleForTesting
  Future<void> Function(PurchaseDetails)? completePurchaseForTest;

  Future<void> _completePurchase(PurchaseDetails purchase) {
    final override = completePurchaseForTest;
    if (override != null) return override(purchase);
    return _iap.completePurchase(purchase);
  }

  /// 스트림 핸들러 안에서 기다리지 않고 종결할 때 쓴다. 종결 실패(이미 큐에서
  /// 빠진 트랜잭션, StoreKit 채널 예외 등)는 로그만 남긴다 — 미종결 트랜잭션은
  /// 다음 실행에 스트림으로 다시 내려와 재시도되므로, 처리되지 않은 비동기
  /// 예외로 앱을 흔들 이유가 없다.
  void _completePurchaseInBackground(PurchaseDetails purchase) {
    _completePurchase(purchase).catchError((Object e) {
      debugPrint('트랜잭션 종결 실패 (${purchase.productID}): $e');
    });
  }

  /// purchased/restored 로 내려온 구매가 **실제로 지급해도 되는 것**인지.
  ///
  /// Android 결제 플러그인의 restorePurchases 는 조회한 구매 전부의 status 를
  /// restored 로 덮어쓴다 — Play 에서 아직 승인되지 않은 **PENDING** 구매(가족
  /// 승인 대기, 편의점·현금 지연 결제)까지. 매 실행 복원을 돌리는 이 앱에서는
  /// 보류 결제를 시작만 하고 앱을 재시작하면 평생 이용권이 공짜로 켜지고, 결제가
  /// 거절돼도 남는다. 그래서 Android 는 원래 purchaseState 가 purchased 일 때만
  /// 지급한다. 상품 ID 도 함께 본다 — 상품이 늘어나면 아무 구매나 프리미엄이 된다.
  @visibleForTesting
  static bool isGrantable(PurchaseDetails purchase) {
    if (purchase.productID != premiumMonthlyId) return false;
    if (purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.purchased;
    }
    return true;
  }

  /// Android 원래 상태가 PENDING(승인 대기)인 프리미엄 구매인지.
  static bool _isAndroidPendingPremium(PurchaseDetails purchase) =>
      purchase is GooglePlayPurchaseDetails &&
      purchase.productID == premiumMonthlyId &&
      purchase.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.pending;

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    // Android 시작 복원의 결과(스냅샷)인지 판정한다. 복원 결과는 전부 restored 로
    // 오고(빈 목록 포함), 결제 결과는 purchased/pending/error/canceled 로 온다.
    // 결제 이벤트를 스냅샷으로 오인하면 회수 판정이 틀어지므로 전부-restored 만 본다.
    if (_awaitingRestoreSnapshot &&
        purchaseDetailsList
            .every((p) => p.status == PurchaseStatus.restored)) {
      _awaitingRestoreSnapshot = false;
      if (purchaseDetailsList.any(isGrantable)) {
        _resetEmptyRestoreStrikes();
      } else {
        _onEmptyRestoreSnapshot();
      }
    }

    for (final purchase in purchaseDetailsList) {
      debugPrint('구매 상태: ${purchase.status} - ${purchase.productID}');

      if (purchase.status == PurchaseStatus.pending) {
        // 결제는 접수됐지만 돈이 아직 안 들어온 상태. 지급하지 않고 안내만 한다.
        // 승인되면 purchased 로 다시 온다(앱이 꺼져 있었으면 다음 실행 복원으로).
        if (purchase.productID == premiumMonthlyId) _setPendingApproval(true);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (!isGrantable(purchase)) {
          debugPrint('지급 보류: ${purchase.productID} (상태 미완료 또는 다른 상품)');
          // 앱을 껐다 켜도 승인 대기 안내가 이어지게 한다 — Android 복원은
          // PENDING 구매도 restored 로 내려준다.
          if (_isAndroidPendingPremium(purchase)) _setPendingApproval(true);
          continue;
        }
        // 저장이 끝난 뒤에 트랜잭션을 종결한다. 순서가 뒤바뀌면 저장 전에 앱이
        // 죽었을 때 스토어는 '완료'로 처리했는데 기기에는 구매 근거가 없어,
        // 결제한 유저가 프리미엄을 잃는다.
        grantPremium().then((_) {
          // 저장에 실패했으면 트랜잭션을 종결하지 않는다.
          // 종결해버리면 스토어는 '완료'로 처리하는데 기기에는 구매 근거가 없어
          // 재시작 후 프리미엄이 사라지고 복구 경로도 함께 사라진다.
          // 미종결로 두면 다음 실행에 스트림으로 다시 내려와 재시도된다.
          if (!_lastSaveSucceeded) {
            debugPrint('구매 저장 실패 — 트랜잭션을 종결하지 않고 다음 실행에 재시도한다');
            return;
          }
          if (purchase.pendingCompletePurchase) {
            _completePurchaseInBackground(purchase);
          }
        });
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (purchase.productID == premiumMonthlyId) _setPendingApproval(false);
        if (purchase.status == PurchaseStatus.error) {
          debugPrint('구매 실패: ${purchase.error?.message}');
          _setPurchaseError(purchase.error?.message ?? '구매에 실패했습니다');
        } else {
          debugPrint('구매 취소됨');
        }
        // 실패·취소 트랜잭션도 종결해야 한다. StoreKit 은 error/canceled 도
        // pendingCompletePurchase 로 내려주는데, 종결하지 않으면 큐에 남아
        // 앱을 켤 때마다 재전달되고 취소한 유저마다 하나씩 계속 쌓인다.
        if (purchase.pendingCompletePurchase) {
          _completePurchaseInBackground(purchase);
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
