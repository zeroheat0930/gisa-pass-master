import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/services/database_service.dart';

/// "복원 기출 랜덤 20문제" 는 실제 시험처럼 푸는 모드다.
/// 여기에 AI 예상문제가 한 문제라도 섞이면 **실전이라는 말이 거짓이 된다.**
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;

  setUp(() async {
    // 실제 에셋으로 채운 DB 를 쓴다. 스텁을 쓰면 "정말 복원 기출만 나오는가" 를
    // 확인할 수 없다 — 그게 이 테스트의 유일한 목적이다.
    db = DatabaseService();
  });

  test('복원 기출로만 20문제를 뽑는다', () async {
    final picked =
        await db.getRandomQuestions(20, source: Question.sourceRestored);

    expect(picked, hasLength(20));
    expect(picked.every((q) => q.isRestored), isTrue,
        reason: 'AI 예상이 섞이면 실전 모의고사가 아니다: '
            '${picked.where((q) => !q.isRestored).map((q) => '${q.year}-${q.round}').toList()}');
  });

  test('출처를 안 주면 예전처럼 전체에서 뽑는다', () async {
    // 기존 '전체 랜덤 20문제' 동작이 그대로여야 한다.
    final picked = await db.getRandomQuestions(20);
    expect(picked, hasLength(20));
  });

  test('여러 번 뽑으면 같은 20문제만 나오지는 않는다', () async {
    // 매번 같은 문제가 나오면 모의고사로서 의미가 없다.
    final a = await db.getRandomQuestions(20, source: Question.sourceRestored);
    final b = await db.getRandomQuestions(20, source: Question.sourceRestored);

    final idsA = a.map((q) => q.id).toSet();
    final idsB = b.map((q) => q.id).toSet();
    expect(idsA, isNot(equals(idsB)),
        reason: '420문항에서 20개를 두 번 뽑아 완전히 같을 확률은 사실상 0이다');
  });

  test('회차별로 골라 푸는 경로도 복원 기출만 준다', () async {
    final q2020 = await db.getQuestionsByRound(2020, 1,
        source: Question.sourceRestored);

    expect(q2020, hasLength(20), reason: '실기는 회차당 20문항이다');
    expect(q2020.every((q) => q.isRestored), isTrue);
    expect(q2020.every((q) => q.year == 2020 && q.round == 1), isTrue);
  });
}
