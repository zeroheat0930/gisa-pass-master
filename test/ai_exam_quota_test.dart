import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/ai_exam_quota.dart';

/// 구독 화면은 AI 실전 모의고사를 유료 전용으로 광고하는데 코드에는 게이트가 없어서
/// 무료 유저가 무제한으로 쓰고 있었다(결제 유저 입장에선 산 보람이 없는 상태).
/// 완전히 막으면 쓰던 기능을 빼앗는 것이라 하루 1회는 열어둔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('무료 유저', () {
    test('첫 응시는 허용된다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AiExamQuota.canStart(isPremium: false), isTrue);
      expect(await AiExamQuota.remainingToday(), AiExamQuota.freeAttemptsPerDay);
    });

    test('하루 한도를 쓰면 막힌다', () async {
      SharedPreferences.setMockInitialValues({});

      for (var i = 0; i < AiExamQuota.freeAttemptsPerDay; i++) {
        expect(await AiExamQuota.canStart(isPremium: false), isTrue);
        await AiExamQuota.consume(isPremium: false);
      }

      expect(await AiExamQuota.canStart(isPremium: false), isFalse,
          reason: '한도를 넘으면 막혀야 한다');
      expect(await AiExamQuota.remainingToday(), 0);
    });

    test('날짜가 바뀌면 다시 열린다', () async {
      SharedPreferences.setMockInitialValues({});
      await AiExamQuota.consume(isPremium: false);
      expect(await AiExamQuota.canStart(isPremium: false), isFalse);

      // 저장된 날짜를 과거로 돌려 '다음 날'을 재현
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_exam_quota_date', '2000-01-01');

      expect(await AiExamQuota.canStart(isPremium: false), isTrue,
          reason: '날짜가 바뀌면 무료 응시가 회복되어야 한다');
      expect(await AiExamQuota.usedToday(), 0);
    });
  });

  group('프리미엄 유저', () {
    test('횟수 제한이 없다', () async {
      SharedPreferences.setMockInitialValues({});

      for (var i = 0; i < 10; i++) {
        expect(await AiExamQuota.canStart(isPremium: true), isTrue);
        await AiExamQuota.consume(isPremium: true);
      }

      expect(await AiExamQuota.canStart(isPremium: true), isTrue);
    });

    test('프리미엄 응시는 무료 한도를 깎지 않는다', () async {
      SharedPreferences.setMockInitialValues({});

      await AiExamQuota.consume(isPremium: true);
      await AiExamQuota.consume(isPremium: true);

      expect(await AiExamQuota.usedToday(), 0,
          reason: '프리미엄 응시가 무료 카운트를 소모하면 안 된다');
      expect(await AiExamQuota.canStart(isPremium: false), isTrue);
    });
  });
}
