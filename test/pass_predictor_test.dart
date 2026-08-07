import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/models/study_stats.dart';
import 'package:gisa_pass_master/services/pass_predictor.dart';

/// 실기는 100점 만점에 60점 합격이다.
/// "정답률 47%"보다 "지금 보면 47점, 합격까지 13점"이 훨씬 강한 동기부여가 된다.
StudyStats stats({
  required int solved,
  required int correct,
  Map<String, double> typeAccuracy = const {},
  Map<String, int> typeSolved = const {},
}) =>
    StudyStats(
      totalSolved: solved,
      totalCorrect: correct,
      typeAccuracy: typeAccuracy,
      typeSolved: typeSolved,
      totalAvailable: 1000,
    );

void main() {
  group('표본이 부족할 때', () {
    test('예측하지 않는다', () {
      final p = PassPredictor.predict(stats(solved: 5, correct: 5));
      expect(p.grade, PassGrade.insufficient);
      expect(p.score, 0);
    });

    test('5문제 전부 맞혀도 합격 확실이라고 말하지 않는다', () {
      final p = PassPredictor.predict(stats(solved: 5, correct: 5));
      expect(p.isPassing, isFalse,
          reason: '표본 5개로 합격을 단정하면 유저를 속이는 것이다');
    });
  });

  group('점수 환산', () {
    test('표본이 적으면 합격선 쪽으로 보정된다', () {
      // 20문제 전부 정답이어도 100점이 되지 않는다
      final p = PassPredictor.predict(stats(solved: 20, correct: 20));
      expect(p.score, lessThan(100));
      expect(p.score, greaterThan(PassPredictor.passingScore));
    });

    test('표본이 커지면 보정이 옅어진다', () {
      final small = PassPredictor.predict(stats(solved: 25, correct: 25));
      final large = PassPredictor.predict(stats(solved: 500, correct: 500));
      expect(large.score, greaterThan(small.score),
          reason: '표본이 쌓일수록 실제 실력에 가까워져야 한다');
    });

    test('전부 틀려도 0점 미만으로 내려가지 않는다', () {
      final p = PassPredictor.predict(stats(solved: 100, correct: 0));
      expect(p.score, greaterThanOrEqualTo(0));
      expect(p.isPassing, isFalse);
    });
  });

  group('합격까지 남은 점수', () {
    test('합격선 아래면 남은 점수를 알려준다', () {
      final p = PassPredictor.predict(stats(solved: 200, correct: 80)); // 40%
      expect(p.isPassing, isFalse);
      expect(p.gap, PassPredictor.passingScore - p.score);
      expect(p.gap, greaterThan(0));
    });

    test('합격선을 넘으면 남은 점수는 0', () {
      final p = PassPredictor.predict(stats(solved: 200, correct: 180)); // 90%
      expect(p.isPassing, isTrue);
      expect(p.gap, 0);
    });
  });

  group('유형별 배점 반영', () {
    test('배점이 큰 유형을 틀리면 점수가 더 크게 깎인다', () {
      // 전체 정답률은 같지만, 배점 40% 인 코드분석만 약한 경우가 더 낮아야 한다
      final weakCode = PassPredictor.predict(stats(
        solved: 300,
        correct: 210,
        typeAccuracy: {'code_reading': 40, 'sql': 90, 'short_answer': 90},
        typeSolved: {'code_reading': 100, 'sql': 100, 'short_answer': 100},
      ));
      final weakShort = PassPredictor.predict(stats(
        solved: 300,
        correct: 210,
        typeAccuracy: {'code_reading': 90, 'sql': 90, 'short_answer': 40},
        typeSolved: {'code_reading': 100, 'sql': 100, 'short_answer': 100},
      ));
      expect(weakCode.score, lessThan(weakShort.score),
          reason: '코드분석 배점(40%)이 단답형(30%)보다 크다');
    });
  });

  group('등급 판정', () {
    test('70점 이상이면 안전', () {
      final p = PassPredictor.predict(stats(solved: 500, correct: 450));
      expect(p.grade, PassGrade.safe);
    });

    test('합격선 근처면 borderline', () {
      final p = PassPredictor.predict(stats(solved: 500, correct: 320)); // 64%
      expect(p.grade, PassGrade.borderline);
    });

    test('합격선 미만이면 danger', () {
      final p = PassPredictor.predict(stats(solved: 500, correct: 150));
      expect(p.grade, PassGrade.danger);
    });
  });
}
