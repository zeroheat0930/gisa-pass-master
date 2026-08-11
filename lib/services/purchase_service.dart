import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('구매 에러: $error'),
    );

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
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _iap.restorePurchases();
      } else {
        await _autoRestoreOnce();
      }
    } catch (e) {
      debugPrint('IAP 초기화 실패: $e');
      _error = '스토어 초기화 실패';
      notifyListeners();
    }
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
    _adService?.setPremium(true);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
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

  Future<void> buyPremium() async {
    try {
      // 이전 시도의 실패 메시지를 지운다. 남겨두면 이번 결제가 정상 진행 중인데도
      // 화면이 옛 에러 스낵바를 띄운다.
      _error = null;

      // 상품이 없으면 재로딩 시도
      if (_products.isEmpty) {
        await reloadProducts();
      }

      if (!_available || _products.isEmpty) {
        _error = '구매할 수 있는 상품이 없습니다. 잠시 후 다시 시도해주세요.';
        notifyListeners();
        return;
      }

      final product = _products.first;

      debugPrint('구매 시작: ${product.id} - ${product.price}');
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('구매 실패: $e');
      _error = '구매 처리 중 오류가 발생했습니다';
      notifyListeners();
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
          _error = '스토어에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
          notifyListeners();
          return false;
        }
      }
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('구매 복원 실패: $e');
      _error = '구매 복원에 실패했습니다. 잠시 후 다시 시도해주세요.';
      notifyListeners();
      return false;
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      debugPrint('구매 상태: ${purchase.status} - ${purchase.productID}');

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
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
            _iap.completePurchase(purchase);
          }
        });
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('구매 실패: ${purchase.error?.message}');
        _error = purchase.error?.message ?? '구매에 실패했습니다';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.canceled) {
        debugPrint('구매 취소됨');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
