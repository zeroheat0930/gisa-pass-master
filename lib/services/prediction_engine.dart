import '../models/question.dart';

/// 2026 1회차 출제 예측 엔진
/// 우선순위 점수 = 빈도(0.4) + 최신성(0.3) + 유형가중(0.2) + 취약도(0.1)
class PredictionEngine {
  // 연도별 최신성 점수
  static double _recencyScore(int year) {
    if (year >= 2025) return 1.0;
    if (year == 2024) return 0.7;
    if (year == 2023) return 0.4;
    return 0.2; // 2022년 이전
  }

  // 문제 유형별 가중치
  static double _typeWeight(String questionType) {
    switch (questionType) {
      case 'code_reading':
        return 1.0;
      case 'sql':
        return 0.9;
      case 'short_answer':
        return 0.7;
      default:
        return 0.5;
    }
  }

  /// 우선순위 점수 계산
  /// frequency: question.frequencyWeight (0~1)
  /// recency: 출제 연도 기반
  /// type_weight: 문제 유형 기반
  /// weakness: 사용자 오답률 (errorRates map에서 조회)
  double calculatePriorityScore(
    Question question,
    double errorRate, // 0.0 ~ 1.0
  ) {
    final frequency = question.frequencyWeight; // 이미 0~1 범위
    final recency = _recencyScore(question.year);
    final typeWeight = _typeWeight(question.questionType);
    final weakness = errorRate.clamp(0.0, 1.0);

    return (frequency * 0.4) +
        (recency * 0.3) +
        (typeWeight * 0.2) +
        (weakness * 0.1);
  }

  /// 우선순위 순으로 정렬된 문제 목록 반환 (내림차순)
  /// [errorRates]: questionId -> 오답률 (0.0~1.0)
  List<Question> getPrioritizedQuestions(
    List<Question> questions,
    Map<int, double> errorRates,
  ) {
    // 점수 계산 후 내림차순 정렬
    final scored = questions.map((q) {
      final errorRate = errorRates[q.id] ?? 0.0;
      final score = calculatePriorityScore(q, errorRate);
      return _ScoredQuestion(q, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.question).toList();
  }

  /// answer_records 기반 문제별 오답률 계산
  /// [records]: questionId -> (총 풀이 수, 오답 수)
  static Map<int, double> buildErrorRates(
    Map<int, ({int total, int wrong})> recordSummary,
  ) {
    final result = <int, double>{};
    for (final entry in recordSummary.entries) {
      final total = entry.value.total;
      final wrong = entry.value.wrong;
      result[entry.key] = total > 0 ? wrong / total : 0.0;
    }
    return result;
  }
}

/// 한 세션에 출제할 문제를 고른다.
///
/// **정렬 결과를 그대로 잘라 쓰면 안 된다.** 우선순위 점수는 빈도·최신성·유형가중이
/// 문항마다 고정이고 약점만 0.1 가중치로 흔들어서 사실상 결정적이다. 전체를 정렬해
/// 상위 N개를 자르면 매 세션 완전히 똑같은 문제만 나오고, 나머지 수백 문항은
/// 영영 출제되지 않는다.
///
/// 그렇다고 전체에서 무작위로 뽑으면 '출제 예측'이 무의미해진다.
/// 그래서 상위 우선순위 풀에서 무작위로 뽑는다 — 예측은 살리고 반복은 피한다.
extension PredictionSessionSelection on PredictionEngine {
  /// 세션 크기의 [poolMultiplier] 배수만큼 상위 문항을 후보로 두고 그 안에서 섞는다.
  List<Question> selectForSession(
    List<Question> questions,
    Map<int, double> errorRates, {
    int sessionSize = 50,
    int poolMultiplier = 4,
  }) {
    final prioritized = getPrioritizedQuestions(questions, errorRates);
    if (prioritized.length <= sessionSize) return prioritized;

    final poolSize = (sessionSize * poolMultiplier).clamp(sessionSize, prioritized.length);
    final pool = prioritized.take(poolSize).toList()..shuffle();
    final selected = pool.take(sessionSize).toList();

    // 고른 뒤에는 다시 우선순위 순서로 보여준다 (중요한 문제부터 풀도록).
    final rank = <int?, int>{
      for (var i = 0; i < prioritized.length; i++) prioritized[i].id: i,
    };
    selected.sort(
      (a, b) => (rank[a.id] ?? 1 << 30).compareTo(rank[b.id] ?? 1 << 30),
    );
    return selected;
  }
}

/// 내부 헬퍼: 점수가 부여된 문제
class _ScoredQuestion {
  final Question question;
  final double score;
  _ScoredQuestion(this.question, this.score);
}
