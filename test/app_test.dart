import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';
import 'package:gisa_pass_master/services/ad_service.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';
import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/services/answer_checker.dart';

// 예전에는 여기에 채점 로직 사본이 있었다. 사본을 검증하면 실제 앱이 틀려도
// 테스트는 통과하므로, 정본(AnswerChecker)을 그대로 호출한다.
bool isCorrectAnswer(String userAnswer, String correctAnswer) =>
    AnswerChecker.isCorrect(userAnswer, correctAnswer);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── 시나리오 1: 연타 테스트 ───
  test('submitAnswer 20번 연속 호출해도 크래시 없음', () async {
    final db = DatabaseService();
    final provider = StudyProvider(
      db: db,
      predictionEngine: PredictionEngine(),
      spacedRepetitionService: SpacedRepetitionService(db),
      adService: AdService(),
    );

    for (int i = 0; i < 20; i++) {
      await provider.submitAnswer('test_$i');
    }
    expect(provider.isAnswered, false);
  });

  // ─── 시나리오 2: 광고 설정 ───
  // v1.5.0+20 에서 간격을 5 → 3 으로 단축. 테스트 이름에 숫자를 박지 않아 다시 썩지 않게 한다.
  test('전면광고 간격 설정', () {
    expect(AppConfig.adIntervalQuestions, 3);
  });

  test('AdService shouldShowAds 정상 동작', () {
    final adService = AdService();
    expect(AdService.adsEnabled, true);
    expect(adService.isPremium, false);

    adService.setPremium(true);
    expect(adService.shouldShowAds, false);
    expect(adService.isPremium, true);

    adService.setPremium(false);
    expect(adService.isPremium, false);
  });

  // ─── 시나리오 3: nextQuestion 빈 리스트 ───
  test('빈 리스트에서 nextQuestion 크래시 없음', () {
    final db = DatabaseService();
    final provider = StudyProvider(
      db: db,
      predictionEngine: PredictionEngine(),
      spacedRepetitionService: SpacedRepetitionService(db),
      adService: AdService(),
    );
    provider.nextQuestion();
    expect(provider.questionIndex, 0);
  });

  // ─── 시나리오 4: 답안 비교 로직 ───
  group('답안 비교', () {
    test('기본 일치', () {
      expect(isCorrectAnswer('8 3', '8 3'), true);
    });

    test('대소문자 무시', () {
      expect(isCorrectAnswer('Hello', 'hello'), true);
    });

    test('내부 공백 차이', () {
      expect(isCorrectAnswer('8  3', '8 3'), true);
    });

    test('공백 없는 한글', () {
      expect(isCorrectAnswer('상호배제', '상호 배제'), true);
    });

    test('줄바꿈 답안', () {
      expect(isCorrectAnswer('개발, 6000, 영업, 4500', '개발, 6000\n영업, 4500'), true);
    });

    // 순서 무시는 지문이 "모두 쓰시오" 류일 때만 허용된다.
    // 지문 정보 없이 호출하면 순서를 지켜야 한다(안전한 기본값).
    test('지문 없이는 순서를 지켜야 한다', () {
      expect(isCorrectAnswer('일관성, 원자성, 지속성, 독립성', '원자성, 일관성, 독립성, 지속성'), false);
    });

    test('"모두 쓰시오" 지문이면 순서 무관', () {
      expect(
        AnswerChecker.isCorrect(
          '일관성, 원자성, 지속성, 독립성',
          '원자성, 일관성, 독립성, 지속성',
          questionType: 'short_answer',
          questionText: '트랜잭션의 ACID 특성 4가지를 모두 쓰시오.',
        ),
        true,
      );
    });

    test('오답', () {
      expect(isCorrectAnswer('TCP', 'UDP'), false);
    });

    test('앞뒤 공백', () {
      expect(isCorrectAnswer('  120  ', '120'), true);
    });

    test('숫자 답안', () {
      expect(isCorrectAnswer('3300', '3300'), true);
    });
  });

  // ─── 시나리오 5: Config 시험 일정 ───
  test('nextExam 자동 전환', () {
    final exam = AppConfig.nextExam;
    expect(exam.year, greaterThanOrEqualTo(2026));
    expect(exam.round, greaterThanOrEqualTo(1));
  });

  // ─── 시나리오 6: DB 생성 ───
  test('DatabaseService 생성 크래시 없음', () {
    final db = DatabaseService();
    expect(db, isNotNull);
  });
}
