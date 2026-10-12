import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/restored_exam_coverage.dart';

import 'support/active_source.dart';

/// 날짜·표시 정본 배선. 숫자·연도를 화면이나 엔진에 박아두면 해가 바뀌거나
/// 회차가 추가될 때 한쪽만 고쳐진다 — 그걸 소스 수준에서 막는다.
void main() {
  tearDown(() => AppConfig.nowForTest = null);

  group('복원 기출 회차·문항 문구', () {
    const screens = [
      'lib/screens/home_screen.dart',
      'lib/screens/past_exam_screen.dart',
    ];

    test('홈·기출 화면이 같은 정본(RestoredExamCoverage)을 쓴다', () {
      for (final path in screens) {
        final src = activeSource(path);
        expect(src.contains('RestoredExamCoverage.watch()'), isTrue,
            reason: '$path 가 정본을 구독하지 않는다');
        for (final hardcoded in ['21개 회차', '420문항', '2020~2026']) {
          expect(src.contains(hardcoded), isFalse,
              reason: '$path 에 "$hardcoded" 가 다시 박혔다');
        }
      }
    });

    test('에셋에서 센 값이 실제 데이터와 맞는다', () {
      final list = (jsonDecode(
        File(RestoredExamCoverage.assetPath).readAsStringSync(),
      ) as List)
          .cast<Map<String, dynamic>>();
      final c = RestoredExamCoverage.summarize(list)!;

      final rounds = {for (final q in list) (q['year'], q['round'])};
      final years = list.map((q) => q['year'] as int);
      expect(c.questions, list.length);
      expect(c.rounds, rounds.length);
      expect(c.fromYear, years.reduce((a, b) => a < b ? a : b));
      expect(c.toYear, years.reduce((a, b) => a > b ? a : b));
      expect(RestoredExamCoverage.fullLabel(c),
          '${c.fromYear}~${c.toYear}년 ${c.rounds}개 회차 · ${c.questions}문항');
    });

    test('AI 문항이 섞여도 restored 만 센다', () {
      final c = RestoredExamCoverage.summarize([
        {'year': 2024, 'round': 1, 'source': 'restored'},
        {'year': 2025, 'round': 2, 'source': 'restored'},
        {'year': 2030, 'round': 3, 'source': 'ai'},
      ])!;
      expect(c, (fromYear: 2024, toYear: 2025, rounds: 2, questions: 2));
    });
  });

  test('학습 플랜 Day 탭은 연타 가드를 거친다', () {
    final src = activeSource('lib/screens/study_plan_screen.dart');
    expect(src.contains('onDayTap: _onDayTap'), isTrue,
        reason: '가드 없는 _startDayMission 을 직접 물면 퀴즈 화면이 두 번 쌓인다');
    expect(src.contains('if (_isNavigating) return;'), isTrue);
  });

  group('예측 엔진 최신성 가중치는 올해 기준', () {
    Question q(int year) => Question(
          year: year,
          round: 1,
          subject: 's',
          questionType: 'sql',
          questionText: 't',
          answer: 'a',
          explanation: 'e',
        );

    test('2028년에는 2025년 기출이 더 이상 최신이 아니다', () {
      final engine = PredictionEngine();
      AppConfig.nowForTest = () => DateTime(2026, 6, 1);
      final s2025in2026 = engine.calculatePriorityScore(q(2025), 0);
      AppConfig.nowForTest = () => DateTime(2028, 6, 1);
      final s2025in2028 = engine.calculatePriorityScore(q(2025), 0);
      final s2027in2028 = engine.calculatePriorityScore(q(2027), 0);

      expect(s2025in2028, lessThan(s2025in2026));
      expect(s2027in2028, s2025in2026, reason: '작년 기출은 늘 최고 점수');
    });

    test('엔진 소스에 연도 숫자가 박혀 있지 않다', () {
      final src = activeSource('lib/services/prediction_engine.dart');
      expect(RegExp(r'year\s*[><=]=?\s*20\d\d').hasMatch(src), isFalse);
    });
  });
}
