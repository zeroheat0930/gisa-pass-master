import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/services/review_prompt_service.dart';

/// 리뷰 요청 조건 검증.
///
/// 시스템 리뷰 다이얼로그는 1년에 노출 횟수가 제한된다. 조건이 헐거워져서
/// 낮은 점수 직후나 설치 당일에 묻게 되면, 그 유저에게 다시 물을 기회까지 함께
/// 날아간다. 그래서 경계값(59%/60%, 29문항, 89일/91일)을 못박아둔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 22, 10);

  group('shouldRequest (순수 조건)', () {
    test('정답률 59% 면 묻지 않고 60% 면 묻는다', () {
      expect(
        ReviewPromptService.shouldRequest(
          sessionTotal: 100,
          sessionCorrect: 59,
          cumulativeSolved: 100,
          now: now,
        ),
        isFalse,
        reason: '합격선 미만에서 묻는 요청은 별점을 깎는다',
      );
      expect(
        ReviewPromptService.shouldRequest(
          sessionTotal: 100,
          sessionCorrect: 60,
          cumulativeSolved: 100,
          now: now,
        ),
        isTrue,
      );
    });

    test('20문항 세션의 경계도 같다 (11/20 = 55% false, 12/20 = 60% true)', () {
      bool at(int correct) => ReviewPromptService.shouldRequest(
            sessionTotal: 20,
            sessionCorrect: correct,
            cumulativeSolved: 100,
            now: now,
          );
      expect(at(11), isFalse);
      expect(at(12), isTrue);
    });

    test('누적 29문항이면 묻지 않고 30문항이면 묻는다', () {
      bool at(int cumulative) => ReviewPromptService.shouldRequest(
            sessionTotal: 20,
            sessionCorrect: 20,
            cumulativeSolved: cumulative,
            now: now,
          );
      expect(at(29), isFalse, reason: '써보지도 않은 유저에게 묻는 꼴이다');
      expect(at(30), isTrue);
    });

    test('마지막 요청 후 89일이면 묻지 않고 91일이면 묻는다', () {
      bool after(int days) => ReviewPromptService.shouldRequest(
            sessionTotal: 20,
            sessionCorrect: 20,
            cumulativeSolved: 100,
            lastRequestedAt: now.subtract(Duration(days: days)),
            now: now,
          );
      expect(after(89), isFalse);
      expect(after(91), isTrue);
    });

    test('한 번도 요청한 적이 없으면 쿨다운을 따지지 않는다', () {
      expect(
        ReviewPromptService.shouldRequest(
          sessionTotal: 20,
          sessionCorrect: 20,
          cumulativeSolved: 100,
          lastRequestedAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('푼 문항이 0이면 묻지 않는다', () {
      expect(
        ReviewPromptService.shouldRequest(
          sessionTotal: 0,
          sessionCorrect: 0,
          cumulativeSolved: 100,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('requestIfEligible (저장소 연동)', () {
    late int opened;

    setUp(() {
      opened = 0;
      ReviewPromptService.debugOpenStoreReview = () async {
        opened++;
        return true;
      };
    });

    tearDown(() => ReviewPromptService.debugOpenStoreReview = null);

    test('누적이 모자라면 요청하지 않지만 누적은 쌓인다', () async {
      SharedPreferences.setMockInitialValues({});

      final requested = await ReviewPromptService.requestIfEligible(
        sessionTotal: 20,
        sessionCorrect: 20,
        now: now,
      );

      expect(requested, isFalse);
      expect(opened, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ReviewPromptService.solvedTotalKey), 20);
      expect(prefs.getString(ReviewPromptService.lastRequestedKey), isNull);
    });

    test('조건을 만족하면 요청하고 시각을 남긴다', () async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 20,
      });

      final requested = await ReviewPromptService.requestIfEligible(
        sessionTotal: 20,
        sessionCorrect: 20,
        now: now,
      );

      expect(requested, isTrue);
      expect(opened, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ReviewPromptService.solvedTotalKey), 40);
      expect(
        prefs.getString(ReviewPromptService.lastRequestedKey),
        now.toIso8601String(),
      );
    });

    test('스토어가 못 띄우면 쿨다운을 태우지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 100,
      });
      ReviewPromptService.debugOpenStoreReview = () async => false;

      final requested = await ReviewPromptService.requestIfEligible(
        sessionTotal: 20,
        sessionCorrect: 20,
        now: now,
      );

      expect(requested, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ReviewPromptService.lastRequestedKey), isNull,
          reason: '띄우지도 못한 요청으로 90일을 버리면 안 된다');
    });

    test('취소되면(다른 다이얼로그가 떴다) 요청하지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        ReviewPromptService.solvedTotalKey: 100,
      });

      final requested = await ReviewPromptService.requestIfEligible(
        sessionTotal: 20,
        sessionCorrect: 20,
        isCancelled: () => true,
        now: now,
      );

      expect(requested, isFalse);
      expect(opened, 0, reason: '쿼터 다이얼로그와 겹치면 둘 다 무시당한다');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ReviewPromptService.lastRequestedKey), isNull);
    });
  });
}
