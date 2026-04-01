import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService extends ChangeNotifier {
  static const String premiumMonthlyId = 'gisa_pass_premium_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool _isPremium = false;
  List<ProductDetails> _products = [];
  bool _loading = false;

  bool get isPremium => _isPremium;
  bool get available => _available;
  List<ProductDetails> get products => _products;
  bool get loading => _loading;

  /// 초기화 (웹에서는 비활성)
  Future<void> initialize() async {
    if (kIsWeb) return;

    _available = await _iap.isAvailable();
    if (!_available) return;

    // 구매 스트림 구독
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('구매 에러: $error'),
    );

    // 상품 정보 로드
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    _loading = true;
    notifyListeners();

    final response = await _iap.queryProductDetails({premiumMonthlyId});
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('상품을 찾을 수 없음: ${response.notFoundIDs}');
    }
    _products = response.productDetails;

    _loading = false;
    notifyListeners();
  }

  /// 프리미엄 구매
  Future<void> buyPremium() async {
    if (!_available || _products.isEmpty) return;

    final product = _products.firstWhere(
      (p) => p.id == premiumMonthlyId,
      orElse: () => _products.first,
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 구매 복원
  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        notifyListeners();

        // 구매 완료 처리
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('구매 실패: ${purchase.error?.message}');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
