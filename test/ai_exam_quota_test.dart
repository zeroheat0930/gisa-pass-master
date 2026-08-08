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

  // 광고 보상으로 얻는 보너스 응시.
  // 새 수익원이면서 무료 유저가 유료 기능을 체험하는 통로다.
  // 다만 무제한이면 프리미엄을 살 이유가 사라지므로 상한을 둔다.
  group('광고 보상 보너스', () {
    test('보너스를 받으면 한 번 더 응시할 수 있다', () async {
      SharedPreferences.setMockInitialValues({});
      await AiExamQuota.consume(isPremium: false);
      expect(await AiExamQuota.canStart(isPremium: false), isFalse);

      expect(await AiExamQuota.grantBonus(), isTrue);
      expect(await AiExamQuota.canStart(isPremium: false), isTrue);
    });

    test('하루 보너스 상한을 넘으면 더 받을 수 없다', () async {
      SharedPreferences.setMockInitialValues({});
      for (var i = 0; i < AiExamQuota.maxBonusPerDay; i++) {
        expect(await AiExamQuota.grantBonus(), isTrue);
      }
      expect(await AiExamQuota.grantBonus(), isFalse,
          reason: '무제한이면 프리미엄을 살 이유가 사라진다');
      expect(await AiExamQuota.canEarnBonus(isPremium: false), isFalse);
    });

    test('프리미엄은 보너스가 필요 없다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AiExamQuota.canEarnBonus(isPremium: true), isFalse);
    });

    test('날짜가 바뀌면 보너스도 초기화된다', () async {
      SharedPreferences.setMockInitialValues({});
      await AiExamQuota.grantBonus();
      expect(await AiExamQuota.bonusToday(), 1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_exam_quota_date', '2000-01-01');

      expect(await AiExamQuota.bonusToday(), 0);
    });
  });

  // QA 프로브가 잡아낸 회귀.
  // consume 과 grantBonus 가 각자 날짜를 갱신하면서 자기 카운터만 리셋해서,
  // 어제 얻은 보너스가 오늘 것으로 둔갑했다. 광고를 안 보고 응시권이 생기는 경로.
  group('날짜 롤오버 — 사용횟수와 보너스가 함께 초기화된다', () {
    Future<void> pretendYesterday() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_exam_quota_date', '2000-01-01');
    }

    test('어제 보너스는 오늘로 이월되지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      await AiExamQuota.grantBonus();
      await AiExamQuota.grantBonus();
      await pretendYesterday();

      // 오늘 무료 1회 사용 — 여기서 날짜가 오늘로 갱신된다
      await AiExamQuota.consume(isPremium: false);

      expect(await AiExamQuota.bonusToday(), 0,
          reason: '광고를 안 봤으면 오늘 보너스는 0 이어야 한다');
      expect(await AiExamQuota.canStart(isPremium: false), isFalse,
          reason: '무료 1회를 썼으면 더 못 봐야 한다');
    });

    test('어제 사용횟수도 오늘로 이월되지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      await AiExamQuota.consume(isPremium: false);
      await pretendYesterday();

      // 오늘 보너스를 받으면 여기서도 날짜가 갱신된다
      await AiExamQuota.grantBonus();

      expect(await AiExamQuota.usedToday(), 0,
          reason: '어제 쓴 횟수가 오늘 발목을 잡으면 안 된다');
      expect(await AiExamQuota.canStart(isPremium: false), isTrue);
    });
  });
}
