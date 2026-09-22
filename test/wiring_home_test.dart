import 'package:flutter_test/flutter_test.dart';

import 'support/active_source.dart';

/// 홈 화면 배치 순서 배선 테스트.
///
/// 레이아웃 테스트(`home_first_screen_test.dart`)는 좌표로 결과를 보지만,
/// 여기서는 **소스 상의 순서** 자체를 잡는다. 다음 사람이 "정보 카드가 위에
/// 있어야 읽기 좋다"며 되돌려도 즉시 빨간불이 뜨게 하는 게 목적이다.
void main() {
  const path = 'lib/screens/home_screen.dart';

  int firstIndexOf(String source, String needle) {
    final i = source.indexOf(needle);
    expect(i, isNonNegative, reason: '$path 에서 $needle 를 찾지 못했다');
    return i;
  }

  test('AI 실전 모의고사가 회차별 합격률보다 먼저 배치된다', () {
    final source = activeSource(path);

    expect(
      firstIndexOf(source, '_AiPredictionButton('),
      lessThan(firstIndexOf(source, '_PassRateButton(')),
      reason: '유료 입구가 정보 카드 뒤로 내려가면 첫 화면에서 사라진다',
    );
  });

  test('AI 실전 모의고사가 합격 예측 점수 카드보다 먼저 배치된다', () {
    final source = activeSource(path);

    expect(
      firstIndexOf(source, '_AiPredictionButton('),
      lessThan(firstIndexOf(source, 'PassScoreCard(')),
      reason: '재배치 전 순서(점수 카드 → 학습 플랜 → AI)로 되돌아간 것',
    );
  });
}
