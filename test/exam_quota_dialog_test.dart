import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/services/ai_exam_quota.dart';
import 'package:gisa_pass_master/widgets/exam_quota_dialog.dart';

// 리워드 광고 **보상 지급 배선** 검증.
//
// 이 연결은 어떤 테스트에도 없었다. `if (!watched)` 가드를 지워도(광고를 안 봐도
// 지급), `grantBonus` 호출을 지워도(끝까지 봤는데 미지급) 135건이 전부 녹색이었다.
// 여기서 시청 결과 → 지급의 연결 자체를 검증한다.

class _FakeAdService extends AdService {
  bool watchedResult = true;
  int showCalls = 0;

  @override
  bool get shouldShowAds => true;

  @override
  bool get isRewardedReady => true;

  @override
  void loadRewardedAd() {}

  @override
  Future<bool> showRewardedAd() async {
    showCalls++;
    return watchedResult;
  }
}

void main() {
  late _FakeAdService ads;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ads = _FakeAdService();
    setGlobalAdService(ads);
  });

  /// 다이얼로그를 띄우고 '광고 보고 1회 더'를 눌러 결과를 받는다.
  Future<bool> watchAdFlow(WidgetTester tester) async {
    late Future<bool> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                result = ExamQuotaDialog.show(
                  context,
                  isPremium: false,
                  onSeePremium: () {},
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('광고 보고 1회 더'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('광고를 끝까지 보면 응시권 1회가 지급된다', (tester) async {
    ads.watchedResult = true;

    final earned = await watchAdFlow(tester);

    expect(ads.showCalls, 1, reason: '광고 표시 자체가 호출되어야 한다');
    expect(earned, isTrue);
    expect(await AiExamQuota.bonusToday(), 1,
        reason: '시청했는데 grantBonus 가 안 불리면 유저가 속는다');
  });

  testWidgets('광고를 끝까지 보지 않으면 지급되지 않는다', (tester) async {
    ads.watchedResult = false;

    final earned = await watchAdFlow(tester);

    expect(earned, isFalse);
    expect(await AiExamQuota.bonusToday(), 0,
        reason: '안 봐도 지급되면 리워드 광고 수익 모델이 무너진다');
  });
}
