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
}
