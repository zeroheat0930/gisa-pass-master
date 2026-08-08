import 'package:flutter_test/flutter_test.dart';
import 'package:gisa_pass_master/models/study_stats.dart';
import 'package:gisa_pass_master/services/pass_predictor.dart';

/// 실기는 100점 만점에 60점 합격이다.
/// "정답률 47%"보다 "지금 보면 47점, 합격까지 13점"이 훨씬 강한 동기부여가 된다.
StudyStats stats({
  required int solved,
  required int correct,
  int? unique,
  Map<String, double> typeAccuracy = const {},
  Map<String, int> typeSolved = const {},
}) =>
    StudyStats(
      totalSolved: solved,
      totalCorrect: correct,
      uniqueSolved: unique ?? solved,
      typeAccuracy: typeAccuracy,
      typeSolved: typeSolved,
      totalAvailable: 1000,
    );

/// 세 유형을 골고루 푼 상태 (배점 커버리지 100%)
Map<String, int> fullCoverage(int each) => {
      'code_reading': each,
      'sql': each,
      'short_answer': each,
    };

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
    test('70점 이상이고 유형을 고루 풀었으면 안전', () {
      final p = PassPredictor.predict(stats(
        solved: 500,
        correct: 450,
        typeAccuracy: {'code_reading': 90, 'sql': 90, 'short_answer': 90},
        typeSolved: fullCoverage(150),
      ));
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

  // QA 확정: 안 푼 유형을 전체 정답률로 대신 채우면, 배점 70%(코드분석+SQL)를
  // 한 문제도 안 푼 유저가 단답형 성적만으로 "합격권" 을 받는다.
  group('유형 커버리지', () {
    test('단답형만 푼 유저를 합격권이라고 하지 않는다', () {
      final p = PassPredictor.predict(stats(
        solved: 300,
        correct: 285, // 95%
        typeAccuracy: {'short_answer': 95},
        typeSolved: {'short_answer': 300},
      ));
      expect(p.grade, isNot(PassGrade.safe),
          reason: '배점 70%를 안 풀어봤는데 합격권이라고 하면 유저를 방심시킨다');
    });

    test('안 푼 유형이 점수를 올려주지 않는다', () {
      // 코드분석만 40% 로 약한 유저. 나머지를 안 풀었다고 점수가 오르면 안 된다.
      final weakOnly = PassPredictor.predict(stats(
        solved: 200,
        correct: 80,
        typeAccuracy: {'code_reading': 40},
        typeSolved: {'code_reading': 200},
      ));
      expect(weakOnly.score, lessThan(PassPredictor.passingScore));
    });
  });

  // QA 확정: 표본에 중복 풀이가 들어가면 축소 보정이 무력화된다.
  group('표본은 고유 문항 수로 센다', () {
    test('같은 문제를 반복 복습해도 표본이 부풀지 않는다', () {
      final repeated = PassPredictor.predict(stats(
        solved: 500, // 총 풀이 수
        correct: 500,
        unique: 20, // 실제로는 20문제만 반복
        typeAccuracy: {'code_reading': 100, 'sql': 100, 'short_answer': 100},
        typeSolved: fullCoverage(170),
      ));
      final genuine = PassPredictor.predict(stats(
        solved: 500,
        correct: 500,
        unique: 500,
        typeAccuracy: {'code_reading': 100, 'sql': 100, 'short_answer': 100},
        typeSolved: fullCoverage(170),
      ));
      expect(repeated.score, lessThan(genuine.score),
          reason: '20문제만 반복한 유저와 500문제를 푼 유저가 같을 수 없다');
      expect(repeated.sampleSize, 20);
    });
  });
}
