/// 정보처리기사 회차별 합격률 (2020년 NCS 개편 이후).
///
/// 숫자는 공개된 국가기술자격 통계에서 옮긴 것이다. 응시자·합격자 수를 함께
/// 담아두고, 합격률이 그 둘과 실제로 맞는지는 테스트가 지킨다 — 옮겨 적다 생긴
/// 오타를 그렇게 잡는다.
///
/// 2020년은 코로나로 일정이 밀려 필기가 1·2회 통합으로 치러졌고 실기는 5회까지
/// 있었다. 그래서 두 종목의 회차 수가 다르다.
library;

class PassRateEntry {
  final int year;

  /// 화면에 그대로 쓰는 회차 이름. 2020년 필기의 '1·2회' 처럼 숫자로
  /// 환원되지 않는 회차가 있어서 int 가 아니라 문자열로 둔다.
  final String roundLabel;

  /// 응시자 수.
  final int taken;

  /// 합격자 수.
  final int passed;

  /// 공표된 합격률(%). taken·passed 로 계산한 값과 일치해야 한다.
  final double rate;

  const PassRateEntry({
    required this.year,
    required this.roundLabel,
    required this.taken,
    required this.passed,
    required this.rate,
  });

  String get label => '$year년 $roundLabel';
}

/// 필기 / 실기 구분.
enum ExamKind {
  written('필기'),
  practical('실기');

  const ExamKind(this.label);
  final String label;
}

class PassRateData {
  const PassRateData._();

  static const List<PassRateEntry> written = [
    PassRateEntry(year: 2020, roundLabel: '1·2회', taken: 20155, passed: 10530, rate: 52.25),
    PassRateEntry(year: 2020, roundLabel: '3회', taken: 15139, passed: 10143, rate: 67.00),
    PassRateEntry(year: 2020, roundLabel: '4회', taken: 7985, passed: 4202, rate: 52.62),
    PassRateEntry(year: 2021, roundLabel: '1회', taken: 18843, passed: 15385, rate: 81.65),
    PassRateEntry(year: 2021, roundLabel: '2회', taken: 14422, passed: 5270, rate: 36.54),
    PassRateEntry(year: 2021, roundLabel: '3회', taken: 18375, passed: 12210, rate: 66.45),
    PassRateEntry(year: 2022, roundLabel: '1회', taken: 19445, passed: 12405, rate: 63.80),
    PassRateEntry(year: 2022, roundLabel: '2회', taken: 14626, passed: 7460, rate: 51.01),
    PassRateEntry(year: 2022, roundLabel: '3회', taken: 14399, passed: 7343, rate: 51.00),
    PassRateEntry(year: 2023, roundLabel: '1회', taken: 23587, passed: 15189, rate: 64.40),
    PassRateEntry(year: 2023, roundLabel: '2회', taken: 18952, passed: 10867, rate: 57.34),
    PassRateEntry(year: 2023, roundLabel: '3회', taken: 17485, passed: 9372, rate: 53.60),
    PassRateEntry(year: 2024, roundLabel: '1회', taken: 26687, passed: 17814, rate: 66.75),
    PassRateEntry(year: 2024, roundLabel: '2회', taken: 20867, passed: 12439, rate: 59.61),
    PassRateEntry(year: 2024, roundLabel: '3회', taken: 18615, passed: 10385, rate: 55.79),
    PassRateEntry(year: 2025, roundLabel: '1회', taken: 25678, passed: 17919, rate: 69.78),
    PassRateEntry(year: 2025, roundLabel: '2회', taken: 20853, passed: 13280, rate: 63.68),
    PassRateEntry(year: 2025, roundLabel: '3회', taken: 19777, passed: 12357, rate: 62.48),
    PassRateEntry(year: 2026, roundLabel: '1회', taken: 21998, passed: 14654, rate: 66.62),
  ];

  static const List<PassRateEntry> practical = [
    PassRateEntry(year: 2020, roundLabel: '1회', taken: 4323, passed: 231, rate: 5.34),
    PassRateEntry(year: 2020, roundLabel: '2회', taken: 12587, passed: 2642, rate: 20.99),
    PassRateEntry(year: 2020, roundLabel: '3회', taken: 14101, passed: 2573, rate: 18.25),
    PassRateEntry(year: 2020, roundLabel: '4회', taken: 4149, passed: 578, rate: 13.93),
    PassRateEntry(year: 2020, roundLabel: '5회', taken: 6297, passed: 1317, rate: 20.91),
    PassRateEntry(year: 2021, roundLabel: '1회', taken: 20125, passed: 7947, rate: 39.49),
    PassRateEntry(year: 2021, roundLabel: '2회', taken: 15281, passed: 4235, rate: 27.71),
    PassRateEntry(year: 2021, roundLabel: '3회', taken: 17539, passed: 4141, rate: 23.61),
    PassRateEntry(year: 2022, roundLabel: '1회', taken: 19039, passed: 4880, rate: 25.63),
    PassRateEntry(year: 2022, roundLabel: '2회', taken: 17639, passed: 2841, rate: 16.11),
    PassRateEntry(year: 2022, roundLabel: '3회', taken: 16629, passed: 3390, rate: 20.39),
    PassRateEntry(year: 2023, roundLabel: '1회', taken: 19318, passed: 5307, rate: 27.47),
    PassRateEntry(year: 2023, roundLabel: '2회', taken: 19904, passed: 3566, rate: 17.92),
    PassRateEntry(year: 2023, roundLabel: '3회', taken: 18866, passed: 3332, rate: 17.66),
    PassRateEntry(year: 2024, roundLabel: '1회', taken: 25188, passed: 9263, rate: 36.78),
    PassRateEntry(year: 2024, roundLabel: '2회', taken: 22682, passed: 6292, rate: 27.74),
    PassRateEntry(year: 2024, roundLabel: '3회', taken: 20875, passed: 4324, rate: 20.71),
    PassRateEntry(year: 2025, roundLabel: '1회', taken: 26391, passed: 4007, rate: 15.18),
    PassRateEntry(year: 2025, roundLabel: '2회', taken: 24815, passed: 6905, rate: 27.83),
    PassRateEntry(year: 2025, roundLabel: '3회', taken: 22652, passed: 5414, rate: 23.90),
    PassRateEntry(year: 2026, roundLabel: '1회', taken: 23898, passed: 4335, rate: 18.14),
  ];

  static List<PassRateEntry> of(ExamKind kind) =>
      kind == ExamKind.written ? written : practical;

  /// 회차 합격률의 산술 평균. "회차를 잘 고르면" 이야기의 기준선이라 회차 단위로 낸다.
  static double roundAverage(ExamKind kind) {
    final rows = of(kind);
    return rows.fold(0.0, (s, e) => s + e.rate) / rows.length;
  }

  /// 전체 누적 합격률 — 응시자 수가 회차마다 크게 달라서 회차 평균과 다르다.
  static double cumulativeRate(ExamKind kind) {
    final rows = of(kind);
    final taken = rows.fold(0, (s, e) => s + e.taken);
    final passed = rows.fold(0, (s, e) => s + e.passed);
    return passed / taken * 100;
  }

  static PassRateEntry highest(ExamKind kind) =>
      of(kind).reduce((a, b) => a.rate >= b.rate ? a : b);

  static PassRateEntry lowest(ExamKind kind) =>
      of(kind).reduce((a, b) => a.rate <= b.rate ? a : b);

  static PassRateEntry latest(ExamKind kind) => of(kind).last;
}
