import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/ad_service.dart';

// 리워드 광고 보상 판정 순서.
//
// onUserEarnedReward 가 닫힘 콜백보다 먼저 온다고 가정했었다. 미디에이션 어댑터에
// 따라 순서가 뒤집히면 끝까지 본 유저의 보상이 사라진다. 어느 순서로 와도 같은
// 결론이 나는지, 중복 완료 방지와 엮여도 처음 결론만 남는지 본다.
// (fake_async 는 직접 의존성이 아니라 짧은 실제 유예로 잰다)
void main() {
  const grace = Duration(milliseconds: 40);

  /// 결론이 났으면 그 값, 아직이면 null.
  RewardedAdResult? peek(RewardedAdSettler s) {
    RewardedAdResult? out;
    s.result.then((r) => out = r);
    return out;
  }

  Future<void> wait(Duration d) => Future<void>.delayed(d);

  test('보상 → 닫힘 순서면 즉시 시청 완료', () async {
    final s = RewardedAdSettler(gracePeriod: grace)
      ..reward()
      ..dismiss();
    expect(s.isSettled, isTrue, reason: '둘 다 왔으면 유예 없이 결론낸다');
    expect(await s.result, RewardedAdResult.earned);
  });

  test('닫힘 → 보상 순서여도 유예 안에 오면 시청 완료', () async {
    final s = RewardedAdSettler(gracePeriod: grace)..dismiss();
    expect(s.isSettled, isFalse, reason: '닫히자마자 이탈로 결론내면 늦게 오는 보상을 놓친다');
    await wait(const Duration(milliseconds: 5));
    s.reward();
    expect(await s.result, RewardedAdResult.earned,
        reason: '순서가 뒤집혔다고 보상을 빼앗으면 유저가 속는다');
  });

  test('닫힌 뒤 유예가 지나도 보상이 없으면 중간 이탈', () async {
    final s = RewardedAdSettler(gracePeriod: grace)..dismiss();
    expect(await s.result, RewardedAdResult.dismissedEarly);
  });

  test('유예가 끝난 뒤 늦게 온 보상은 결론을 바꾸지 않는다', () async {
    final s = RewardedAdSettler(gracePeriod: grace)..dismiss();
    expect(await s.result, RewardedAdResult.dismissedEarly);
    s.reward();
    await wait(Duration.zero);
    expect(await s.result, RewardedAdResult.dismissedEarly,
        reason: '한 번 낸 결론이 뒤집히면 중복 지급·이중 안내가 난다');
  });

  test('표시 실패는 실패로, 뒤따르는 콜백은 무시', () async {
    final s = RewardedAdSettler(gracePeriod: grace)
      ..fail()
      ..reward()
      ..dismiss();
    await wait(grace * 2);
    expect(await s.result, RewardedAdResult.failedToShow);
  });

  test('보상만 오고 닫히지 않았으면 아직 결론내지 않는다', () async {
    final s = RewardedAdSettler(gracePeriod: grace)..reward();
    await wait(grace * 2);
    expect(peek(s), isNull);
    expect(s.isSettled, isFalse, reason: '광고가 화면에 남아 있는데 먼저 지급 흐름으로 가면 안 된다');
  });
}
