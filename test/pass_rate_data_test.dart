import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/data/pass_rate_data.dart';

/// 합격률 표는 손으로 옮겨 적은 숫자다. 옮기다 한 자리 틀리면 화면에는 그럴듯하게
/// 나오고 아무도 눈치채지 못한다. 응시자·합격자와 합격률이 서로 맞는지로 잡는다.
void main() {
  for (final kind in ExamKind.values) {
    group('${kind.label} 합격률 데이터', () {
      final rows = PassRateData.of(kind);

      test('합격률이 합격자/응시자와 일치한다', () {
        final mismatched = <String>[];
        for (final e in rows) {
          final computed = e.passed / e.taken * 100;
          if ((computed - e.rate).abs() > 0.05) {
            mismatched.add(
                '${e.label}: 표기 ${e.rate} vs 계산 ${computed.toStringAsFixed(2)}');
          }
        }
        expect(mismatched, isEmpty,
            reason: '옮겨 적은 숫자가 어긋난다:\n${mismatched.join('\n')}');
      });

      test('합격자가 응시자를 넘지 않는다', () {
        for (final e in rows) {
          expect(e.passed, lessThanOrEqualTo(e.taken), reason: e.label);
          expect(e.taken, greaterThan(0), reason: e.label);
        }
      });

      test('연도가 시간 순으로 정렬되어 있다', () {
        for (var i = 1; i < rows.length; i++) {
          expect(rows[i].year, greaterThanOrEqualTo(rows[i - 1].year),
              reason: '차트 x축이 시간 순이라는 전제가 깨진다');
        }
      });

      test('회차가 중복되지 않는다', () {
        final keys = rows.map((e) => '${e.year}-${e.roundLabel}').toList();
        expect(keys.toSet().length, keys.length, reason: '같은 회차가 두 번 들어갔다');
      });

      test('최고·최저·최신이 실제 값과 맞는다', () {
        final rates = rows.map((e) => e.rate).toList();
        expect(PassRateData.highest(kind).rate, rates.reduce((a, b) => a > b ? a : b));
        expect(PassRateData.lowest(kind).rate, rates.reduce((a, b) => a < b ? a : b));
        expect(PassRateData.latest(kind), rows.last);
      });
    });
  }

  test('2020년은 코로나로 회차 수가 다르다', () {
    // 필기는 1·2회가 통합됐고 실기는 5회까지 있었다. 데이터가 그 사실을 담고 있는지
    // 확인해둔다 — '연 3회' 라고 가정한 코드가 들어오면 여기서 걸린다.
    expect(PassRateData.written.where((e) => e.year == 2020), hasLength(3));
    expect(PassRateData.practical.where((e) => e.year == 2020), hasLength(5));
    expect(PassRateData.written.first.roundLabel, '1·2회');
  });

  test('회차 평균과 누적 합격률은 서로 다르다 (섞어 쓰면 안 된다)', () {
    // 응시자 수가 회차마다 크게 달라서 두 값이 갈린다. 화면에서 어느 쪽을
    // 보여주는지 분명히 하려고 계산을 나눠뒀다.
    expect(PassRateData.roundAverage(ExamKind.practical), closeTo(22.18, 0.01));
    expect(PassRateData.cumulativeRate(ExamKind.practical), closeTo(23.51, 0.01));
    expect(PassRateData.roundAverage(ExamKind.written), closeTo(60.12, 0.01));
    expect(PassRateData.cumulativeRate(ExamKind.written), closeTo(61.25, 0.01));
  });

  test('실기가 필기보다 확실히 어렵다는 사실이 데이터에 남아 있다', () {
    expect(PassRateData.roundAverage(ExamKind.practical),
        lessThan(PassRateData.roundAverage(ExamKind.written)));
  });
}
