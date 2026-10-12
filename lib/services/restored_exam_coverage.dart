import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

/// 복원 기출이 몇 년치·몇 회차·몇 문항인지.
typedef RestoredCoverage = ({
  int fromYear,
  int toYear,
  int rounds,
  int questions,
});

/// '2020~2026년 21개 회차 · 420문항' 문구의 단일 정본.
///
/// 이 숫자를 홈·기출 화면에 각각 박아두면 회차를 추가할 때마다 한쪽만 고쳐진다
/// (이 저장소의 반복된 실패 패턴). 그래서 에셋에서 직접 세고, 두 화면은 이것만 본다.
/// 에셋 로드는 비동기라 끝나기 전에는 [fallback] 을 보여주고, 끝나면
/// [watch] 로 받은 리스너가 다시 그린다.
class RestoredExamCoverage {
  RestoredExamCoverage._();

  static const String assetPath =
      'assets/questions/restored_exam_questions.json';

  /// 로드 전·로드 실패 시 대체값. 에셋을 바꾸면 이것도 맞춰 두면 좋지만,
  /// 틀려도 로드가 끝나는 즉시 실제 값으로 덮인다.
  static const RestoredCoverage fallback =
      (fromYear: 2020, toYear: 2026, rounds: 21, questions: 420);

  static final ValueNotifier<RestoredCoverage> _current =
      ValueNotifier(fallback);
  static Future<void>? _loading;

  /// 화면이 구독할 값. 처음 부를 때 에셋 로드를 시작한다.
  static ValueListenable<RestoredCoverage> watch() {
    ensureLoaded();
    return _current;
  }

  /// 에셋을 한 번만 읽는다. 실패하면 대체값을 유지하고 다음 호출이 재시도한다.
  static Future<void> ensureLoaded() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final c = summarize(list);
      if (c != null) _current.value = c;
    } catch (e) {
      debugPrint('복원 기출 집계 실패 — 대체 문구 유지: $e');
      _loading = null;
    }
  }

  /// 문항 목록에서 연도 범위·회차 수·문항 수를 센다. 복원 기출이 없으면 null.
  /// source 가 적혀 있으면 restored 만 센다(AI 문항이 섞여도 숫자가 부풀지 않게).
  static RestoredCoverage? summarize(Iterable<Map<String, dynamic>> items) {
    final restored = items.where((q) {
      final source = q['source'];
      return source == null || source == Question.sourceRestored;
    }).toList();
    if (restored.isEmpty) return null;

    final rounds = <(int, int)>{};
    var from = 1 << 30;
    var to = 0;
    for (final q in restored) {
      final year = q['year'] as int;
      rounds.add((year, q['round'] as int));
      if (year < from) from = year;
      if (year > to) to = year;
    }
    return (
      fromYear: from,
      toYear: to,
      rounds: rounds.length,
      questions: restored.length,
    );
  }

  /// '2020~2026년 21개 회차'
  static String roundsLabel(RestoredCoverage c) =>
      '${c.fromYear}~${c.toYear}년 ${c.rounds}개 회차';

  /// '2020~2026년 21개 회차 · 420문항'
  static String fullLabel(RestoredCoverage c) =>
      '${roundsLabel(c)} · ${c.questions}문항';

  @visibleForTesting
  static void resetForTest() {
    _loading = null;
    _current.value = fallback;
  }
}
