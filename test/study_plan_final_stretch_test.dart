import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/study_plan_service.dart';

/// 시험이 가까울수록 AI 예상보다 실제로 나왔던 문제를 푸는 편이 낫다.
/// 그 자리는 **'실전 모의고사' 미션**이다.
///
/// 처음에는 "플랜의 마지막 3일" 로 잡았는데 그게 틀렸다. 마지막 날들은 대개
/// '최종 오답 정리'·'가볍게 복습' 이고, 이건 유저 **자신의** 오답과 이력을
/// 다루는 미션이다. 거기에 복원 기출을 밀어넣으면 미션의 목적이 사라진다.
/// 이 파일이 그 실수를 잡았고, 다시 들어오는 것도 막는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('어떤 미션이 복원 기출을 쓰는가', () {
    test('실전 모의고사는 복원 기출로 낸다', () {
      expect(StudyPlanService.usesRestoredPool('14day', 'prediction'), isTrue);
      expect(StudyPlanService.usesRestoredPool('7day', 'prediction'), isTrue);
    });

    test('내 오답·복습 미션은 건드리지 않는다', () {
      // 이 미션들은 유저 자신의 이력이 재료다. 복원 기출로 바꾸면
      // '최종 오답 정리' 가 오답 정리가 아니게 된다.
      for (final q in ['all_wrong', 'wrong', 'review', 'weakness']) {
        expect(StudyPlanService.usesRestoredPool('14day', q), isFalse,
            reason: '$q 는 유저의 풀이 이력으로 내야 한다');
      }
    });

    test('유형별 학습 미션도 건드리지 않는다', () {
      // 여기까지 복원 기출로 좁히면 420문항이 금세 동나고
      // 유형별로 폭넓게 훑는다는 목적이 사라진다.
      for (final q in ['type', 'type_difficulty', 'frequent', 'hard']) {
        expect(StudyPlanService.usesRestoredPool('14day', q), isFalse);
      }
    });

    test('1일 벼락치기는 그 하루가 시험 전날이라 전부 복원 기출이다', () {
      expect(StudyPlanService.usesRestoredPool('1day', 'frequent'), isTrue);
    });
  });

  group('실제로 복원 기출이 나온다', () {
    late StudyPlanService plan;

    setUp(() async {
      plan = StudyPlanService(DatabaseService());
    });

    test('14일 플랜의 실전 모의고사(12일차)는 전부 복원 기출이다', () async {
      await plan.startNewPlan(planType: '14day');
      final questions = await plan.getQuestionsForDay(12);

      expect(questions, isNotEmpty);
      expect(questions.every((q) => q.isRestored), isTrue,
          reason: '실전 모의고사인데 AI 예상이 섞였다: '
              '${questions.where((q) => !q.isRestored).length}문항');
    });

    test('최종 오답 정리(13일차)는 복원 기출로 대체되지 않는다', () async {
      await plan.startNewPlan(planType: '14day');
      final questions = await plan.getQuestionsForDay(13);
      // 풀이 이력이 없으면 랜덤으로 채워지므로 '전부 복원' 이 아니어야 한다.
      expect(questions.every((q) => q.isRestored), isFalse,
          reason: '오답 정리가 복원 기출 모의고사로 바뀌면 안 된다');
    });

    test('유형별 학습(1일차)도 그대로다', () async {
      await plan.startNewPlan(planType: '14day');
      final questions = await plan.getQuestionsForDay(1);
      expect(questions, isNotEmpty);
      expect(questions.any((q) => !q.isRestored), isTrue);
    });

    test('문제 수가 줄지 않는다', () async {
      await plan.startNewPlan(planType: '14day');
      final mission = StudyPlanService.getMissionsForPlanType('14day')
          .firstWhere((m) => m.dayNumber == 12);

      final questions = await plan.getQuestionsForDay(12);
      expect(questions, hasLength(mission.questionCount),
          reason: '미션이 요구한 만큼은 채워야 한다');
    });

    test('같은 문제가 두 번 들어오지 않는다', () async {
      await plan.startNewPlan(planType: '14day');
      final questions = await plan.getQuestionsForDay(12);
      final ids = questions.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length, reason: '중복 문항: $ids');
    });
  });
}
