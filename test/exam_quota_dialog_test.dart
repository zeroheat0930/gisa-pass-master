import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/config.dart';
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

  // ── 안내 문구(P2) ────────────────────────────────────────────────────────
  //
  // 유료 벽에 닿는 유일한 지점이라 문구가 사실과 어긋나면 곧장 환불 사유가 된다.
  // 남은 일수는 AppConfig.daysUntilExam 정본만 쓰고, 시험이 지나 다음 회차로
  // 넘어가면(또는 확정 일정이 아니면) D-Day 문구 자체를 내보내지 않는다.
  group('쿼터 안내 문구', () {
    tearDown(() => AppConfig.nowForTest = null);

    /// 다이얼로그를 띄우기만 하고 닫는다(선택지는 '내일 다시').
    Future<void> openAndClose(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ExamQuotaDialog.show(
                  context,
                  isPremium: false,
                  onSeePremium: () {},
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.tap(find.text('내일 다시'));
      await tester.pumpAndSettle();
    }

    testWidgets('시험이 가까우면 무료 한도와 D-Day 를 사실대로 적는다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 9, 22); // 시험 2026-10-18 확정
      expect(AppConfig.daysUntilExam, 26, reason: '테스트 전제 확인');

      await openAndClose(tester);

      expect(find.textContaining('하루 ${AiExamQuota.freeAttemptsPerDay}회'),
          findsOneWidget,
          reason: '무료 한도는 게이팅 정본 숫자 그대로 적어야 한다');
      expect(find.textContaining('D-${AppConfig.daysUntilExam}'), findsOneWidget,
          reason: '남은 일수는 daysUntilExam 정본을 그대로 쓴다');

      await close(tester);
    });

    testWidgets('광고 보너스를 다 쓴 상태에서도 같은 문구가 나온다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 9, 22);
      for (var i = 0; i < AiExamQuota.maxBonusPerDay; i++) {
        await AiExamQuota.grantBonus();
      }

      await openAndClose(tester);

      expect(find.text('광고 보고 1회 더'), findsNothing, reason: '테스트 전제 확인');
      expect(find.textContaining('하루 ${AiExamQuota.freeAttemptsPerDay}회'),
          findsOneWidget);
      expect(find.textContaining('D-${AppConfig.daysUntilExam}'), findsOneWidget,
          reason: '분기마다 문구를 따로 쓰면 한쪽만 고쳐지는 사고가 난다');

      await close(tester);
    });

    testWidgets('시험이 60일 넘게 남으면 D-Day 문구를 쓰지 않는다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 7, 6); // 다음 확정 시험까지 104일
      expect(AppConfig.daysUntilExam, greaterThan(60), reason: '테스트 전제 확인');
      expect(AppConfig.isExamDateConfirmed, isTrue, reason: '일수 조건만 검증');

      await openAndClose(tester);

      expect(find.textContaining('D-'), findsNothing,
          reason: '시험 직후에는 다음 회차까지 반 년이라 D-Day 가 압박이 아니라 소음이다');
      expect(find.textContaining('하루 ${AiExamQuota.freeAttemptsPerDay}회'),
          findsOneWidget, reason: '무료 한도 자체는 계속 알려준다');

      await close(tester);
    });

    testWidgets('확정 일정이 아니면 D-Day 문구를 쓰지 않는다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2027, 6, 1); // 2027-2회는 추정 일정
      expect(AppConfig.isExamDateConfirmed, isFalse, reason: '테스트 전제 확인');
      expect(AppConfig.daysUntilExam, lessThanOrEqualTo(60),
          reason: '확정 여부 조건만 검증');

      await openAndClose(tester);

      expect(find.textContaining('D-'), findsNothing,
          reason: '추정 날짜로 남은 일수를 단언하면 거짓 표기가 된다');

      await close(tester);
    });
  });
}
