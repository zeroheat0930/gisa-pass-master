import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/purchase_service.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  void _onSubscribe(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('앱에서 구매할 수 있습니다'),
          backgroundColor: AppConfig.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final purchaseService = context.read<PurchaseService>();

    // 상품이 아직 로딩 안 됐으면 재시도
    if (purchaseService.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('스토어 연결 중... 잠시만 기다려주세요'),
          backgroundColor: AppConfig.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
      await purchaseService.reloadProducts();
    }

    // buyPremium 내부에서도 재로딩을 시도함
    await purchaseService.buyPremium();

    if (purchaseService.error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(purchaseService.error!),
          backgroundColor: AppConfig.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _onRestore(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('앱에서 복원할 수 있습니다'),
          backgroundColor: AppConfig.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final purchaseService = context.read<PurchaseService>();

    // 결과를 기다렸다가 보여준다. 요청도 안 됐는데(스토어 연결 실패)
    // '복원 중...'만 띄우면 유저는 성공한 줄 알고 기다리다 이탈한다.
    final requested = await purchaseService.restorePurchases();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(requested
            ? '구매 복원 중... 구매 이력이 있으면 곧 반영됩니다'
            : purchaseService.error ?? '구매 복원에 실패했습니다'),
        backgroundColor: AppConfig.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch — 구매가 완료되면 이 화면이 즉시 '이용 중'으로 바뀌어야 한다.
    final isPremium = context.watch<PurchaseService>().isPremium;

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '프리미엄',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero header
            _HeroHeader(),
            const SizedBox(height: 28),

            // Plan comparison
            _PlanComparisonCard(),
            const SizedBox(height: 28),

            // Feature list
            const _FeatureList(),
            const SizedBox(height: 32),

            // CTA — 이미 구매한 유저에게 '프리미엄 시작하기'를 다시 보여주면
            // 중복 결제로 오해하게 된다. 구매 상태를 반영한다.
            if (isPremium)
              const _PremiumActiveBanner()
            else ...[
              _CtaButton(onTap: () => _onSubscribe(context)),
              const SizedBox(height: 16),

              // Restore purchases (이미 프리미엄이면 필요 없다)
              Center(
                child: TextButton(
                  onPressed: () => _onRestore(context),
                  child: const Text(
                    '구매 복원',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Header ────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppConfig.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppConfig.primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: AppConfig.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '기사패스마스터 프리미엄',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'AI 실전 모의고사 무제한 +\n광고 없이 합격에만 집중하세요',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Plan Comparison Card ────────────────────────────────────────────────────

class _PlanComparisonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlanTile(
            label: '무료',
            price: '₩0',
            period: '',
            color: const Color(0xFF9E9E9E),
            isPremium: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanTile(
            label: '프리미엄',
            price: '₩4,900',
            period: '',
            color: AppConfig.primaryColor,
            isPremium: true,
          ),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String label;
  final String price;
  final String period;
  final Color color;
  final bool isPremium;

  const _PlanTile({
    required this.label,
    required this.price,
    required this.period,
    required this.color,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: isPremium
            ? AppConfig.primaryColor.withValues(alpha: 0.12)
            : AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPremium
              ? AppConfig.primaryColor.withValues(alpha: 0.6)
              : AppConfig.borderColor,
          width: isPremium ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '추천',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: price,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: period,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feature List ────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const List<_FeatureRow> _features = [
    _FeatureRow(label: '기본 문제 풀기', free: true, premium: true),
    _FeatureRow(label: '오답노트', free: true, premium: true),
    _FeatureRow(label: '기본 통계', free: true, premium: true),
    // 실제로 게이트가 있는 것만 적는다. 'AI 무제한 예측 문제'·'기출 유형 심층
    // 분석'을 유료 전용으로 표기했었지만 코드에 게이트가 없거나 기능 자체가
    // 없었다 — 판매 문구와 코드가 다르면 환불 분쟁·심사 리스크가 된다.
    _FeatureRow(label: '광고 제거', free: false, premium: true),
    _FeatureRow(label: 'AI 실전 모의고사 무제한', free: false, premium: true),
    _FeatureRow(label: '학습 플랜 Day 4 이후', free: false, premium: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConfig.borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppConfig.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(color: AppConfig.borderColor, width: 1),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    '기능',
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '무료',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '프리미엄',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppConfig.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Feature rows
          ...List.generate(_features.length, (i) {
            final feature = _features[i];
            final isLast = i == _features.length - 1;
            return _FeatureRowWidget(feature: feature, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _FeatureRow {
  final String label;
  final bool free;
  final bool premium;
  const _FeatureRow({
    required this.label,
    required this.free,
    required this.premium,
  });
}

class _FeatureRowWidget extends StatelessWidget {
  final _FeatureRow feature;
  final bool isLast;

  const _FeatureRowWidget({
    required this.feature,
    required this.isLast,
  });

  Widget _icon(bool available) {
    if (available) {
      return Icon(Icons.check_rounded, color: AppConfig.correctColor, size: 18);
    }
    return Icon(Icons.close_rounded, color: Colors.grey[700], size: 18);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: AppConfig.borderColor, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              feature.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _icon(feature.free),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _icon(feature.premium),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CTA Button ─────────────────────────────────────────────────────────────

/// 이미 프리미엄인 유저에게 보여주는 상태 배너.
/// 결제한 사람에게 '프리미엄 시작하기' 버튼을 계속 노출하면 결제가 안 된 줄 알고
/// 다시 누르게 된다(문의·환불로 이어짐).
class _PremiumActiveBanner extends StatelessWidget {
  const _PremiumActiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppConfig.correctColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppConfig.correctColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, color: AppConfig.correctColor, size: 22),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '프리미엄 이용 중',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '모든 기능이 열려 있습니다',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CtaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppConfig.primaryColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: const Text(
                '프리미엄 시작하기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '한 번 구매로 평생 이용',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
