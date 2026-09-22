import 'package:flutter_test/flutter_test.dart';

import 'support/active_source.dart';

/// 복원 기출 결과 화면의 **배선** 검증.
///
/// 위젯 테스트는 "보인다/눌린다"를 잡지만, 유료 입구를 통째로 지우거나 게이트를
/// 우회하는 새 경로를 만드는 변경은 화면을 조금 바꾸면 초록불로 지나간다.
/// 여기서는 소스에 무엇이 있어야 하고 무엇이 있으면 안 되는지를 못박는다.
/// (주석은 걷어낸 뒤 본다 — 호출을 주석 처리해 되돌려도 통과하면 의미가 없다)
void main() {
  const screen = 'lib/screens/past_exam_screen.dart';
  late String source;

  setUpAll(() => source = activeSource(screen));

  group('유료 퍼널 배선 (P0)', () {
    const launcher = 'lib/services/ai_exam_launcher.dart';

    test('결과 화면이 AI 모의고사·구독 두 입구를 모두 물고 있다', () {
      for (final symbol in ['startAiExam(', 'SubscriptionScreen']) {
        expect(source.contains(symbol), isTrue,
            reason: '$symbol 로 가는 링크가 사라지면 이 화면은 다시 막다른 길이 된다');
      }
    });

    test('AI 모의고사 진입이 쿼터 게이트를 거친다', () {
      // 게이트는 정본에만 있다. 화면이 사본을 들고 있으면 한쪽만 고쳐진다.
      final code = activeSource(launcher);
      expect(code.contains('AiExamQuota.canStart'), isTrue,
          reason: '정본에서 게이트가 빠지면 무료 하루 1회 제한이 무의미해진다');
      expect(code.contains('ExamQuotaDialog.show('), isTrue,
          reason: '쿼터 소진 시 광고 보상 진입점을 띄워야 한다');
      for (final copied in ['AiExamQuota.canStart', 'AiPredictionScreen(']) {
        expect(source.contains(copied), isFalse,
            reason: '$screen 이 $copied 을 직접 갖고 있다 — 정본($launcher)만 쓸 것');
      }
    });
  });

  group('리뷰 요청 배선 (P4)', () {
    test('호출부는 정확히 한 곳이다', () {
      final calls = 'ReviewPromptService.'.allMatches(source).length;
      expect(calls, 1,
          reason: '호출 지점이 늘면 세션당 1회 규칙과 상호배제 규칙이 둘 다 깨진다');
    });

    test('자체 별점 위젯을 만들지 않는다', () {
      // 앱이 직접 별점을 받아 고득점자만 스토어로 보내는 것은 정책 위반이다.
      for (final banned in ['Icons.star', 'RatingBar', 'starRating']) {
        expect(source.contains(banned), isFalse,
            reason: '$banned — 스토어 기본 다이얼로그만 쓴다');
      }
      final service = activeSource('lib/services/review_prompt_service.dart');
      expect(service.contains('InAppReview.instance'), isTrue);
    });
  });

  group('시간 표기 정본 (P3-lite)', () {
    test('새 시간 포맷 함수를 정의하지 않는다', () {
      // 정본은 lib/utils/duration_format.dart 의 top-level formatElapsed 하나다.
      final declarations =
          RegExp(r'String\s+_?\w*[Ff]ormat\w*\s*\(\s*Duration').allMatches(source);
      expect(declarations, isEmpty,
          reason: '화면마다 포맷을 복붙해 한쪽만 고치는 사고가 반복됐다: '
              '${declarations.map((m) => m.group(0)).toList()}');
    });

    test('경과 시간은 정본 함수로 찍는다', () {
      expect(source.contains('formatElapsed('), isTrue);
    });
  });
}
