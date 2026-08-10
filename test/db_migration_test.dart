import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gisa_pass_master/services/database_service.dart';

/// v1.5.4 회귀 방지 — 기존 유저의 앱을 벽돌로 만들던 마이그레이션 버그.
///
/// createStudyPlanTables 는 study_plan 을 **plan_type 컬럼을 포함해서** 만든다.
/// 그런데 v1.5.4 이전의 ensurePlanTypeColumn 은 무조건
/// `ALTER TABLE study_plan ADD COLUMN plan_type` 을 실행했다.
///
/// DB v1·v2 유저는 onUpgrade 에서 테이블이 새로 만들어진 뒤 이 함수가 호출되므로
/// "duplicate column name: plan_type" 예외가 났고, onUpgrade 에서 던진 예외는
/// openDatabase 전체를 실패시킨다. 즉 그 유저의 DB 는 영원히 열리지 않는다.
///
/// 실기기로 재현하려면 구버전 빌드를 설치해야 해서 확인이 어렵다. 여기서 대신 잡는다.
void main() {
  // rootBundle 로 에셋(문제 JSON)을 읽으려면 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> openMemoryDb() =>
      databaseFactory.openDatabase(inMemoryDatabasePath);

  group('study_plan plan_type 마이그레이션', () {
    test('테이블이 없으면 만들어준다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      await DatabaseService.ensurePlanTypeColumn(db);

      final cols = await db.rawQuery('PRAGMA table_info(study_plan)');
      expect(cols, isNotEmpty, reason: 'study_plan 이 생성되어야 한다');
      expect(cols.any((c) => c['name'] == 'plan_type'), isTrue);
    });

    test('plan_type 이 이미 있으면 예외 없이 통과한다 (v1·v2 유저 경로)', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      // onUpgrade 의 oldVersion<3 분기가 최신 스키마로 테이블을 만든 상태 재현
      await DatabaseService.createStudyPlanTables(db);

      // 이어서 oldVersion<5 분기가 호출된다. 여기서 터지면 DB 가 영영 안 열린다.
      await expectLater(
        DatabaseService.ensurePlanTypeColumn(db),
        completes,
        reason: 'duplicate column 예외가 나면 안 된다',
      );
    });

    test('plan_type 이 없는 구 스키마에는 컬럼을 추가한다 (v3·v4 유저 경로)', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      // v3 당시의 study_plan 스키마 — plan_type 이 없었다
      await db.execute('''
        CREATE TABLE study_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT NOT NULL,
          current_day INTEGER DEFAULT 1
        )
      ''');

      await DatabaseService.ensurePlanTypeColumn(db);

      final cols = await db.rawQuery('PRAGMA table_info(study_plan)');
      expect(cols.any((c) => c['name'] == 'plan_type'), isTrue,
          reason: '구 스키마에는 컬럼이 추가되어야 한다');
    });

    test('여러 번 호출해도 안전하다 (멱등)', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      await DatabaseService.createStudyPlanTables(db);
      await DatabaseService.ensurePlanTypeColumn(db);
      await DatabaseService.ensurePlanTypeColumn(db);
      await DatabaseService.ensurePlanTypeColumn(db);

      final cols = await db.rawQuery('PRAGMA table_info(study_plan)');
      final planTypeCount =
          cols.where((c) => c['name'] == 'plan_type').length;
      expect(planTypeCount, 1, reason: 'plan_type 컬럼은 정확히 하나여야 한다');
    });

    // 위 테스트들이 헛돌지 않는다는 증명.
    // v1.5.4 이전 구현(무조건 ALTER)을 그대로 재현하면 실제로 예외가 나야 한다.
    // 여기가 통과하지 못하면 이 파일의 다른 테스트도 버그를 잡을 수 없다는 뜻이다.
    test('구 구현(무조건 ALTER)은 실제로 예외를 던진다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      await DatabaseService.createStudyPlanTables(db);

      await expectLater(
        db.execute(
            "ALTER TABLE study_plan ADD COLUMN plan_type TEXT DEFAULT '14day'"),
        throwsA(isA<DatabaseException>()),
        reason: '이 예외가 openDatabase 를 실패시켜 DB 가 영영 열리지 않았다',
      );
    });

    test('기존 데이터가 보존된다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);

      await db.execute('''
        CREATE TABLE study_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT NOT NULL,
          current_day INTEGER DEFAULT 1
        )
      ''');
      await db.insert('study_plan', {
        'started_at': '2026-08-01T00:00:00.000',
        'current_day': 7,
      });

      await DatabaseService.ensurePlanTypeColumn(db);

      final rows = await db.query('study_plan');
      expect(rows.length, 1, reason: '진행 중이던 학습 플랜이 사라지면 안 된다');
      expect(rows.first['current_day'], 7);
      expect(rows.first['plan_type'], '14day', reason: '기본값이 채워져야 한다');
    });
  });

  // 문제 데이터는 최초 설치 때 1회만 시딩되어, 정답 오류를 고쳐도 기존 유저에게
  // 반영되지 않았다(DB v6 마이그레이션으로 해결). 이 동기화는 id 를 반드시 보존해야
  // 한다. answer_records / bookmarks / spaced_repetition 이 question_id 로 참조하므로,
  // id 가 바뀌면 유저의 학습 이력이 엉뚱한 문제에 붙는다.
  group('questions 에셋 동기화 (DB v6)', () {
    Future<void> createQuestionsTable(Database db) => db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        round INTEGER NOT NULL,
        subject TEXT NOT NULL,
        question_type TEXT NOT NULL,
        question_text TEXT NOT NULL,
        code_snippet TEXT,
        code_language TEXT,
        answer TEXT NOT NULL,
        explanation TEXT NOT NULL,
        difficulty INTEGER DEFAULT 3,
        frequency_weight REAL DEFAULT 0.5
      )
    ''');

    test('틀린 정답이 갱신되고 id 는 유지된다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);
      await createQuestionsTable(db);

      // 에셋에서 실제 문항을 가져와, 정답만 틀린 상태로 심어둔다 (구버전 유저 재현)
      final raw = await rootBundle.loadString('assets/questions/c_questions.json');
      final target = (json.decode(raw) as List)[22];

      final id = await db.insert('questions', {
        'year': target['year'],
        'round': target['round'],
        'subject': target['subject'],
        'question_type': target['questionType'],
        'question_text': target['questionText'],
        'code_snippet': target['codeSnippet'],
        'code_language': target['codeLanguage'],
        'answer': 'WRONG_OLD_ANSWER',
        'explanation': '옛 해설',
      });

      await DatabaseService.syncQuestionsFromAssets(db);

      final rows =
          await db.query('questions', where: 'id = ?', whereArgs: [id]);
      expect(rows.length, 1, reason: '행이 사라지면 안 된다');
      expect(rows.first['answer'], target['answer'],
          reason: '에셋의 정답으로 갱신되어야 한다');
      expect(rows.first['answer'], isNot('WRONG_OLD_ANSWER'));
      expect(rows.first['id'], id, reason: 'id 가 바뀌면 학습 이력이 어긋난다');
    });

    test('유저의 학습 이력이 계속 같은 문제를 가리킨다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);
      await createQuestionsTable(db);
      await db.execute('''
        CREATE TABLE answer_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id INTEGER NOT NULL,
          is_correct INTEGER NOT NULL,
          user_answer TEXT NOT NULL,
          answered_at TEXT NOT NULL
        )
      ''');

      final raw = await rootBundle.loadString('assets/questions/c_questions.json');
      final target = (json.decode(raw) as List)[22];

      final qid = await db.insert('questions', {
        'year': target['year'],
        'round': target['round'],
        'subject': target['subject'],
        'question_type': target['questionType'],
        'question_text': target['questionText'],
        'code_snippet': target['codeSnippet'],
        'code_language': target['codeLanguage'],
        'answer': 'WRONG_OLD_ANSWER',
        'explanation': '옛 해설',
      });
      await db.insert('answer_records', {
        'question_id': qid,
        'is_correct': 0,
        'user_answer': 'threefourother',
        'answered_at': '2026-08-01T00:00:00.000',
      });

      await DatabaseService.syncQuestionsFromAssets(db);

      final joined = await db.rawQuery(
        'SELECT q.question_text FROM answer_records r '
        'JOIN questions q ON q.id = r.question_id',
      );
      expect(joined.length, 1, reason: '풀이 기록이 문제를 잃으면 안 된다');
      expect(joined.first['question_text'], target['questionText']);
    });

    test('DB 에 없던 문항은 새로 추가된다', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);
      await createQuestionsTable(db);

      await DatabaseService.syncQuestionsFromAssets(db);

      final count = _firstInt(
          await db.rawQuery('SELECT COUNT(*) FROM questions'));
      expect(count, 1000, reason: '에셋의 전체 문항이 들어와야 한다');
    });

    test('두 번 실행해도 문항이 중복되지 않는다 (멱등)', () async {
      final db = await openMemoryDb();
      addTearDown(db.close);
      await createQuestionsTable(db);

      await DatabaseService.syncQuestionsFromAssets(db);
      await DatabaseService.syncQuestionsFromAssets(db);

      final count = _firstInt(
          await db.rawQuery('SELECT COUNT(*) FROM questions'));
      expect(count, 1000, reason: '재실행이 문항을 복제하면 안 된다');
    });

    test('감사에서 확정된 정답 오류가 실제로 고쳐져 있다', () async {
      Future<Map<String, dynamic>> item(String file, int i) async {
        final raw = await rootBundle.loadString('assets/questions/$file');
        return (json.decode(raw) as List)[i] as Map<String, dynamic>;
      }

      expect((await item('c_questions.json', 22))['answer'], 'threefourother');
      expect((await item('java_questions.json', 55))['answer'], '-80');
      expect((await item('sql_questions.json', 1))['answer'], '1003, 95');
      expect((await item('sql_questions.json', 64))['answer'], '3, 185');
      expect((await item('sql_questions.json', 67))['answer'],
          '전자, 3, 541666.67\n가구, 2, 225000');
      expect((await item('sql_questions.json', 74))['answer'],
          '이, 6000\n박, 5000\n김, 4000');
    });
  });

  // v1.6.0 QA 확정: 데이터 동기화가 oldVersion<6 마이그레이션에만 묶여 있어서,
  // DB 가 v6 이 된 순간부터는 에셋 정답을 고쳐도 기존 유저에게 영영 반영되지
  // 않았다. 이제 questionDataRevision 비교로 매 실행 판단한다.
  group('데이터 리비전 동기화 (DB v6 이후)', () {
    Future<Database> dbWithStaleQuestion() async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute("""
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          year INTEGER NOT NULL, round INTEGER NOT NULL,
          subject TEXT NOT NULL, question_type TEXT NOT NULL,
          question_text TEXT NOT NULL, code_snippet TEXT, code_language TEXT,
          answer TEXT NOT NULL, explanation TEXT NOT NULL,
          difficulty INTEGER DEFAULT 3, frequency_weight REAL DEFAULT 0.5
        )
      """);
      final raw = await rootBundle.loadString('assets/questions/c_questions.json');
      final target = (json.decode(raw) as List)[22];
      await db.insert('questions', {
        'year': target['year'],
        'round': target['round'],
        'subject': target['subject'],
        'question_type': target['questionType'],
        'question_text': target['questionText'],
        'code_snippet': target['codeSnippet'],
        'code_language': target['codeLanguage'],
        'answer': 'STALE_ANSWER',
        'explanation': '옛 해설',
      });
      return db;
    }

    // 동기화가 없던 문항 999개를 INSERT 하므로, 심어둔 문항만 집어서 본다.
    Future<String> answerOf(Database db) async =>
        (await db.query('questions', where: 'id = 1')).single['answer']
            as String;

    test('리비전이 다르면(v6 유저가 업데이트를 받으면) 데이터가 갱신된다', () async {
      final db = await dbWithStaleQuestion();
      addTearDown(db.close);

      // DB 는 이미 v6 — runMigrations 는 아무것도 하지 않는 상태를 재현
      await DatabaseService().runMigrations(db, 6, 6);
      expect(await answerOf(db), 'STALE_ANSWER',
          reason: '마이그레이션만으로는 v6 유저에게 수정이 도달하지 않는다');

      await DatabaseService.syncQuestionsIfRevisionChanged(db);
      expect(await answerOf(db), isNot('STALE_ANSWER'),
          reason: '리비전 동기화가 이 구멍을 막아야 한다');
    });

    test('리비전이 같으면 다시 동기화하지 않는다 (매 실행 비용 방지)', () async {
      final db = await dbWithStaleQuestion();
      addTearDown(db.close);

      await DatabaseService.syncQuestionsIfRevisionChanged(db);
      // 동기화 완료 후 일부러 다시 오염시킨다
      await db.update('questions', {'answer': 'TAMPERED'});

      await DatabaseService.syncQuestionsIfRevisionChanged(db);
      expect(await answerOf(db), 'TAMPERED',
          reason: '리비전이 같으면 손대지 않아야 게이트가 실제로 동작하는 것이다');
    });

    test('동기화 성공 후에만 리비전이 기록된다', () async {
      final db = await dbWithStaleQuestion();
      addTearDown(db.close);

      await DatabaseService.syncQuestionsIfRevisionChanged(db);
      final rows = await db.query('app_meta',
          where: 'key = ?', whereArgs: ['question_data_revision']);
      expect(rows.single['value'], '${DatabaseService.questionDataRevision}');
    });
  });
}

int? _firstInt(List<Map<String, Object?>> rows) =>
    rows.isEmpty ? null : rows.first.values.first as int?;
