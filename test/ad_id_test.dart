import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/ad_service.dart';

/// 광고 단위 ID 가 실 단위인지 지킨다.
///
/// 리워드 광고는 v1.6.4 까지 Google 테스트 ID 로 배포되어 있었다. 앱은 정상
/// 동작하고 응시권도 지급되지만 **수익만 0** 이라, 어떤 화면·로그도 이상을
/// 알려주지 않는다. 조용히 돈이 새는 종류의 결함이라 테스트로 못박는다.
///
/// (전면·배너는 처음부터 실 단위였지만 같은 실수가 가능하므로 함께 검사한다)
void main() {
  const testPublisher = AdService.testPublisherPrefix;
  const realPublisher = 'ca-app-pub-5911237489066113';

  test('모든 광고 단위가 Google 테스트 ID 가 아니다', () {
    final offenders = AdService.allAdUnitIds.entries
        .where((e) => e.value.startsWith(testPublisher))
        .map((e) => '${e.key} = ${e.value}')
        .toList();

    expect(offenders, isEmpty,
        reason: '테스트 ID 로 배포하면 그 지면의 수익이 0 이 된다 '
            '(앱은 정상 동작해서 알아채기 어렵다):\n${offenders.join('\n')}');
  });

  test('모든 광고 단위가 이 앱의 퍼블리셔 계정에 속한다', () {
    // 다른 계정 단위를 붙여 넣으면 수익이 남의 계정으로 간다.
    final offenders = AdService.allAdUnitIds.entries
        .where((e) => !e.value.startsWith('$realPublisher/'))
        .map((e) => '${e.key} = ${e.value}')
        .toList();

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('플랫폼별 광고 단위가 서로 겹치지 않는다', () {
    // 복붙 후 한쪽만 고치는 이 코드베이스의 반복 패턴 — 같은 ID 가 두 지면에
    // 쓰이면 통계가 섞이고 한쪽 지면의 실적을 알 수 없게 된다.
    final ids = AdService.allAdUnitIds.values.toList();
    expect(ids.toSet().length, ids.length,
        reason: '중복된 광고 단위 ID 가 있다: ${AdService.allAdUnitIds}');
  });

  test('isRewardedUsingTestId 가 실 ID 를 실 ID 로 보고한다', () {
    expect(AdService.isRewardedUsingTestId, isFalse);
  });
}
