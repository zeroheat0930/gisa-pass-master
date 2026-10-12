import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/ai_exam_quota.dart';
import 'package:gisa_pass_master/services/daily_quota.dart';

// 자정 경계 쿼터.
//
// canStart 판정 뒤 2초 로딩을 거쳐 consume 한다. 23:59:58 에 시작하면 소모가
// 자정을 넘겨 내일 무료 1회를 깎고, 어젯밤 광고로 받은 보너스는 롤오버로 사라졌다.
// 판정 시점의 날짜 키를 consume 에 넘겨 그날 장부에서 깎는지 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final beforeMidnight = DateTime(2026, 10, 12, 23, 59, 58);
  final afterMidnight = DateTime(2026, 10, 13, 0, 0, 1);

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => DailyQuota.nowForTest = null);

  void at(DateTime t) => DailyQuota.nowForTest = () => t;

  test('자정 직전 판정·자정 직후 소모는 전날 쿼터를 깎는다', () async {
    at(beforeMidnight);
    final day = AiExamQuota.dayKey();
    expect(await AiExamQuota.canStart(isPremium: false, day: day), isTrue);

    at(afterMidnight);
    await AiExamQuota.consume(isPremium: false, day: day);

    expect(await AiExamQuota.usedToday(), 0,
        reason: '어제 시작한 응시가 오늘 무료 1회를 먹으면 안 된다');
    expect(await AiExamQuota.canStart(isPremium: false), isTrue);

    at(beforeMidnight);
    expect(await AiExamQuota.usedToday(), 1, reason: '판정한 날 장부에 적혀야 한다');
  });

  test('자정 직전 광고 보너스로 시작한 응시도 전날 보너스에서 깎인다', () async {
    at(beforeMidnight);
    await AiExamQuota.consume(isPremium: false); // 오늘 무료 1회 사용
    expect(await AiExamQuota.grantBonus(), isTrue); // 23:59 광고 시청
    final day = AiExamQuota.dayKey();
    expect(await AiExamQuota.canStart(isPremium: false, day: day), isTrue);

    at(afterMidnight);
    await AiExamQuota.consume(isPremium: false, day: day);

    expect(await AiExamQuota.usedToday(), 0);
    expect(await AiExamQuota.canStart(isPremium: false), isTrue,
        reason: '보너스로 본 응시 때문에 오늘 무료 1회가 사라지면 안 된다');
  });

  test('날짜를 넘기지 않으면 예전처럼 오늘로 깎는다(기존 호출 호환)', () async {
    at(afterMidnight);
    await AiExamQuota.consume(isPremium: false);
    expect(await AiExamQuota.usedToday(), 1);
  });

  test('이미 다음 날 장부가 열렸으면 지난 날짜 소모는 오늘을 건드리지 않는다', () async {
    at(afterMidnight);
    expect(await AiExamQuota.grantBonus(), isTrue); // 오늘 장부가 먼저 열림

    await AiExamQuota.consume(isPremium: false, day: '2026-10-12');

    expect(await AiExamQuota.usedToday(), 0);
    expect(await AiExamQuota.bonusToday(), 1,
        reason: '지난 날짜 기록이 오늘 카운터를 리셋하면 광고로 받은 보너스가 사라진다');
  });
}
