import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'ad_service.dart';

class PurchaseService extends ChangeNotifier {
  static const String premiumMonthlyId = 'gisa_pass_premium_monthly';

  // 관리자 기기: 자동 프리미엄 (결제 불필요)
  static const Set<String> _adminDeviceIds = {
    '91ED9D8E-7430-4194-B9D0-D0099A772E02', // 정동준의 iPhone
  };

  final InAppPurchase _iap = InAppPurchase.instance;
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

  Future<void> initialize() async {
    if (kIsWeb) return;

    // 관리자 기기 체크
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final deviceId = iosInfo.identifierForVendor ?? '';
      debugPrint('Device ID: $deviceId');
      if (_adminDeviceIds.contains(deviceId)) {
        debugPrint('관리자 기기 감지 — 자동 프리미엄 활성화');
        _isPremium = true;
        _adService?.setPremium(true);
        notifyListeners();
        return;
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

      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('구매 에러: $error'),
      );

      await _loadProducts();
    } catch (e) {
      debugPrint('IAP 초기화 실패: $e');
      _error = '스토어 초기화 실패';
      notifyListeners();
    }
  }

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

  Future<void> restorePurchases() async {
    try {
      if (!_available) return;
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('구매 복원 실패: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      debugPrint('구매 상태: ${purchase.status} - ${purchase.productID}');

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        _error = null;
        _adService?.setPremium(true);
        notifyListeners();

        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
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
