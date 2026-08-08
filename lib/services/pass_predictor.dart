import '../models/study_stats.dart';

/// 합격 예측 등급
enum PassGrade {
  /// 아직 판단할 데이터가 부족
  insufficient,

  /// 합격선에 한참 못 미침
  danger,

  /// 합격선 근처 — 조금만 더
  borderline,

  /// 합격 가능
  safe,
}

/// 합격 예측 결과
class PassPrediction {
  /// 예상 점수 (0~100)
  final int score;

  /// 합격까지 남은 점수 (이미 넘었으면 0)
  final int gap;

  final PassGrade grade;

  /// 예측 근거가 된 풀이 수
  final int sampleSize;

  const PassPrediction({
    required this.score,
    required this.gap,
    required this.grade,
    required this.sampleSize,
  });

  bool get isPassing => score >= PassPredictor.passingScore;
}

/// 합격 예측기.
///
/// 정보처리기사 실기는 **100점 만점에 60점 이상**이면 합격이다.
/// 단순 정답률을 그대로 점수로 쓰지 않는다. 실제 시험은 유형별 배점이 다르고,
/// 표본이 적을 때는 정답률이 심하게 출렁이기 때문이다.
class PassPredictor {
  PassPredictor._();

  /// 실기 합격 기준점
  static const int passingScore = 60;

  /// 이 정도는 풀어야 예측에 의미가 있다
  static const int minimumSample = 20;

  /// 실기 유형별 대략 배점 비중.
  /// 코드 분석과 SQL 이 실기 배점의 큰 축이라 단답형보다 무겁게 잡는다.
  static const Map<String, double> _typeWeights = {
    'code_reading': 0.40,
    'sql': 0.30,
    'short_answer': 0.30,
  };

  /// 표본이 적을 때 점수를 합격선 쪽으로 끌어당기는 정도.
  /// 5문제 풀고 100% 맞혔다고 "합격 확실"이라고 말하면 안 된다.
  static const double _priorStrength = 30;

  /// 예측을 신뢰하려면 배점의 이만큼은 실제로 풀어봤어야 한다.
  static const double minimumTypeCoverage = 0.5;

  static PassPrediction predict(StudyStats stats) {
    // **고유 문항 수**를 표본으로 쓴다. 총 풀이 수를 쓰면 같은 20문제를 반복
    // 복습한 유저의 표본이 수백으로 잡혀 축소 보정이 통째로 무력화된다.
    final sample =
        stats.uniqueSolved > 0 ? stats.uniqueSolved : stats.totalSolved;
    if (sample < minimumSample) {
      return PassPrediction(
        score: 0,
        gap: passingScore,
        grade: PassGrade.insufficient,
        sampleSize: sample,
      );
    }

    // 유형별 정답률을 배점 비중으로 가중 평균한다.
    //
    // **풀어본 유형만 센다.** 예전에는 안 푼 유형을 전체 정답률로 대신 채웠는데,
    // 그러면 배점 70%(코드분석+SQL)를 한 문제도 안 푼 유저가 단답형 성적만으로
    // "합격권 86점" 을 받는다. 실제 시험에서는 그 70%를 통째로 날리는 셈이라
    // 예측이 유저를 크게 오도한다.
    final overall = stats.totalAccuracy;
    double weighted = 0;
    double coveredWeight = 0;

    _typeWeights.forEach((type, weight) {
      final solved = stats.typeSolved[type] ?? 0;
      if (solved <= 0) return; // 안 풀어본 유형은 예측 근거가 없다
      weighted += (stats.typeAccuracy[type] ?? overall) * weight;
      coveredWeight += weight;
    });

    // 커버리지가 낮으면 유형 가중을 신뢰할 수 없으므로 전체 정답률로 물러선다.
    final raw = coveredWeight >= minimumTypeCoverage
        ? weighted / coveredWeight
        : overall;

    // 표본이 적으면 합격선 쪽으로 보정한다(베이지안 축소).
    // 표본이 커질수록 보정이 사라진다.
    final shrunk =
        (raw * sample + passingScore * _priorStrength) / (sample + _priorStrength);

    final score = shrunk.round().clamp(0, 100);
    final gap = score >= passingScore ? 0 : passingScore - score;

    // 배점의 절반도 안 풀어봤으면 '합격권' 이라고 단정하지 않는다.
    // 근거가 얇은 낙관은 유저를 방심하게 만든다.
    var grade = _gradeFor(score);
    if (coveredWeight < minimumTypeCoverage && grade == PassGrade.safe) {
      grade = PassGrade.borderline;
    }

    return PassPrediction(
      score: score,
      gap: gap,
      grade: grade,
      sampleSize: sample,
    );
  }

  static PassGrade _gradeFor(int score) {
    if (score >= 70) return PassGrade.safe;
    if (score >= passingScore) return PassGrade.borderline;
    return PassGrade.danger;
  }
}
