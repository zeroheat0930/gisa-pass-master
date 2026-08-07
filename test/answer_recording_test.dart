import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v1.5.4 회귀 방지 — "채점은 하는데 기록은 안 하는" 구조적 누락.
///
/// 문제은행 탭과 AI 예측 모의고사는 답을 채점해 화면에 정오답을 보여주면서도
/// **DB에는 전혀 기록하지 않았다.** 그래서 그 탭에서 아무리 풀어도 통계·오답노트·
/// 스트릭·AI 예측이 전부 0으로 남았다. 메인 탭이라 영향이 컸다.
///
/// 이건 개별 함수의 버그가 아니라 **호출부가 빠진** 문제라서, 서비스 단위 테스트로는
/// 잡히지 않는다(그 함수는 멀쩡히 동작한다). 그래서 불변식 자체를 검사한다:
///
///   "답을 채점하는 곳은 반드시 그 결과를 기록해야 한다"
///
/// 새 퀴즈 화면을 추가하면서 기록을 빠뜨리면 여기서 걸린다.
void main() {
  test('채점하는 모든 화면은 풀이 결과를 기록해야 한다', () {
    final offenders = <String>[];

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();

      // 채점기를 호출한다 = 유저의 답을 정오답 판정한다
      final grades = source.contains('AnswerChecker.isCorrectFor') ||
          source.contains('AnswerChecker.isCorrect(');
      if (!grades) continue;

      // 채점기 정본 파일 자신은 제외
      if (file.path.endsWith('answer_checker.dart')) continue;

      // 기록 경로를 타는가 (StudyProvider.recordAnswer 또는 내부 저장 경로)
      final records = source.contains('recordAnswer') ||
          source.contains('_persistAnswer');

      if (!records) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: '다음 파일은 답을 채점하면서 DB에 기록하지 않는다. '
          'StudyProvider.recordAnswer() 를 호출할 것: $offenders',
    );
  });

  test('채점 로직이 다시 복붙되지 않았는지 확인한다', () {
    // 채점 로직 3벌 중 1벌만 고쳐져서 문제은행 탭이 오답을 뱉었던 것이
    // 이 앱의 반복 실패 패턴이다. 정본 밖에서 같은 정규화를 다시 구현하면 걸린다.
    final offenders = <String>[];

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('answer_checker.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      // 정답 비교용 정규화의 특징적 조합
      if (source.contains("replaceAll('\\n', ', ')") ||
          (source.contains('toLowerCase()') &&
              source.contains("RegExp(r'\\s+')"))) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '채점 정규화가 AnswerChecker 밖에 복제되어 있다. '
          '정본만 쓸 것: $offenders',
    );
  });
}
