import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config.dart';
import '../models/question.dart';
import '../models/answer_record.dart';

class DatabaseService {
  static Database? _database;

  /// 문제 데이터 에셋의 **단일 정본 목록**.
  ///
  /// 최초 시딩(_onCreate)·갱신(syncQuestionsFromAssets)·웹 로드(_loadFromJson)가
  /// 모두 이걸 본다. **테스트도 반드시 이 목록을 쓸 것** — 테스트가 파일 목록을
  /// 따로 적어두면 새 파일을 추가했을 때 검증 밖으로 새어나간다
  /// (실제로 restored_exam_questions.json 20문항이 그렇게 빠질 뻔했다).
  @visibleForTesting
  static const List<String> questionAssetFiles = _questionAssetFiles;

  static const List<String> _questionAssetFiles = [
    'assets/questions/c_questions.json',
    'assets/questions/java_questions.json',
    'assets/questions/python_questions.json',
    'assets/questions/sql_questions.json',
    'assets/questions/short_answer_questions.json',
    // 실제 시험을 응시자들이 복원한 기출. 위 파일들과 달리 AI 생성이 아니다.
    // 각 항목의 "source": "restored" 가 그 구분을 담는다.
    'assets/questions/restored_exam_questions.json',
  ];

  static Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 초기화가 끝나기 전에 두 번째 호출이 들어오면 _initDB 가 2회 실행되어
    // 리비전 동기화가 겹치고 신규 문항이 중복 INSERT 된다. 첫 호출이 만든
    // Future 를 공유하고, 실패 시에만 비워서 다음 호출이 재시도하게 한다.
    final opening = _opening ??= _initDB();
    try {
      final db = await opening;
      _database = db;
      return db;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initDB() async {
    final String path;
    if (kIsWeb) {
      path = AppConfig.dbName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, AppConfig.dbName);
    }

    final db = await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: runMigrations,
    );

    // 문제 데이터 동기화는 DB 버전이 아니라 **데이터 리비전**으로 판단한다.
    //
    // 예전에는 oldVersion < 6 마이그레이션 안에서만 동기화해서, DB 가 v6 이 된
    // 순간부터는 에셋의 정답을 아무리 고쳐도 기존 유저에게 영영 반영되지 않았다.
    // (다음 수정 때마다 DB 버전을 올리는 방식은 사람이 잊어버리는 순간 조용히 깨진다)
    await syncQuestionsIfRevisionChanged(db);

    return db;
  }

  /// 문제 데이터 리비전. **assets/questions/*.json 을 고칠 때마다 1 올릴 것.**
  /// 이 숫자가 기기에 저장된 값과 다르면 앱 시작 시 에셋 기준으로 동기화된다.
  ///
  /// rev 1: v1.5.4 정답 오류 6건 수정
  /// rev 2: sql_questions[135] 정답 3 -> 2
  /// rev 3: c_questions[106] UB 문항 교체에 따른 정답·해설 갱신 (본문은 DB v7 이 처리)
  /// rev 4: 복원 기출(restored_exam_questions.json) 추가 — 기존 유저에게도 내려간다
  /// rev 5: 복원 기출 2026년 1회 20문항 추가
  /// rev 6: 복원 기출 2025년 3회 20문항 추가
  /// rev 7: 복원 기출 2025년 2회 20문항 추가
  /// rev 8: 복원 기출 2025년 1회 20문항 추가
  /// rev 9: 복원 기출 2024년 3·2·1회 60문항 추가
  static const int questionDataRevision = 9;

  static const String _metaTable = 'app_meta';
  static const String _metaKeyRevision = 'question_data_revision';

  /// 기기에 기록된 리비전과 코드의 리비전이 다르면 문제 데이터를 동기화한다.
  /// 같으면 아무 것도 하지 않으므로 매 실행 비용은 SELECT 1회다.
  @visibleForTesting
  static Future<void> syncQuestionsIfRevisionChanged(Database db) async {
    if (kIsWeb) return; // 웹은 JSON 을 직접 읽으므로 항상 최신이다
    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS $_metaTable (key TEXT PRIMARY KEY, value TEXT)');
      final rows = await db.query(_metaTable,
          where: 'key = ?', whereArgs: [_metaKeyRevision]);
      final stored =
          rows.isEmpty ? null : int.tryParse(rows.first['value'] as String? ?? '');
      if (stored == questionDataRevision) return;

      await syncQuestionsFromAssets(db);

      // 동기화가 성공한 뒤에만 리비전을 기록한다.
      // 먼저 기록하면 동기화가 실패해도 "됐다" 고 착각해 영영 재시도하지 않는다.
      await _writeRevision(db);
    } catch (e) {
      debugPrint('문제 데이터 리비전 동기화 실패 (다음 실행에 재시도): $e');
    }
  }

  /// 버전 업그레이드 마이그레이션 (테스트 가능한 진입점).
  ///
  /// 예전에는 이 로직이 onUpgrade 클로저 안에 갇혀 있어서, 개별 마이그레이션
  /// 함수는 테스트하면서도 **그것이 실제로 연결되어 있는지는 아무도 검증하지
  /// 못했다.** 연결을 끊어도 테스트가 전부 통과하는 상태였다.
  @visibleForTesting
  Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 유저는 학습 이력(answer_records)과 복습 큐를 잃는다. **의도된 손실이다.**
      //
      // v1 은 이 저장소의 첫 커밋(v1.3.0, 2026-04)보다도 이전이라 그 시절
      // questions 스키마를 알 방법이 없다. 이력만 남기고 questions 를 다시 심으면
      // question_id 가 새 id 와 어긋나 **풀이 기록이 엉뚱한 문제에 붙는다** —
      // 이력을 잃는 것보다 나쁜 결과다(통계·오답노트가 조용히 거짓말을 한다).
      // 정확히 옮기려면 옛 본문으로 remap 해야 하는데, 알 수 없는 스키마를
      // 추측해 쓰는 코드는 검증할 수도 없다.
      //
      // 대상자는 2026-04 이전 빌드를 설치한 뒤 그 이후로 한 번도 앱을 열지 않은
      // 유저뿐이다. 되살릴 근거가 생기면(v1 스키마 확인) 그때 remap 을 넣을 것.
      await db.execute('DROP TABLE IF EXISTS spaced_repetition');
      await db.execute('DROP TABLE IF EXISTS answer_records');
      await db.execute('DROP TABLE IF EXISTS questions');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 3) {
      await createStudyPlanTables(db);
    }
    if (oldVersion < 4) {
      await _createBookmarkTable(db);
    }
    if (oldVersion < 5) {
      await ensurePlanTypeColumn(db);
    }
    // **버전 순서대로 두면 안 된다.** v6 동기화의 INSERT 가 source 컬럼을 쓰므로
    // 컬럼 추가가 그보다 먼저 실행돼야 한다. 뒤에 두면 v5 이하 유저가 업그레이드할 때
    // "no such column: source" 로 동기화가 통째로 실패한다.
    if (oldVersion < 8) {
      await ensureSourceColumn(db);
    }
    if (oldVersion < 6) {
      // v6 마이그레이션 시점의 동기화. 이후의 데이터 수정 반영은
      // questionDataRevision (매 실행 비교) 이 담당한다 — DB 버전에 묶어두면
      // 버전 올리는 것을 잊는 순간 수정이 기존 유저에게 도달하지 못한다.
      try {
        await syncQuestionsFromAssets(db);
        // 성공했으면 리비전을 여기서 기록한다. 안 남기면 openDatabase 직후의
        // 리비전 검사가 같은 동기화를 한 번 더 돌아 첫 실행 스플래시가 배가된다.
        await _writeRevision(db);
      } catch (e) {
        // onUpgrade 에서 새어나간 예외는 openDatabase 전체를 실패시킨다
        // (v1·v2 duplicate column 사고와 같은 유형). 여기서 삼키면
        // 리비전이 미기록 상태로 남아 다음 리비전 검사가 재시도한다.
        debugPrint('v6 문제 동기화 실패 (리비전 검사가 재시도): $e');
      }
    }
    if (oldVersion < 7) {
      // 본문(codeSnippet) 수정은 리비전 동기화로 불가능하다 — 본문이 매칭 키라서
      // 옛 행이 방치되고 새 행이 중복 INSERT 된다. 그래서 여기서 UPDATE 한다.
      try {
        await fixUndefinedBehaviorQuestion(db);
      } catch (e) {
        debugPrint('v7 문항 교체 실패: $e');
      }
    }
  }

  /// questions.source 컬럼을 보장한다. **멱등이어야 한다** — v1·v2 시절
  /// `ALTER TABLE ADD COLUMN` 을 무조건 실행했다가 duplicate column 예외로
  /// openDatabase 전체가 죽어 앱이 영영 열리지 않던 사고가 있었다.
  @visibleForTesting
  static Future<void> ensureSourceColumn(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(questions)');
    if (cols.any((c) => c['name'] == 'source')) return;
    await db.execute(
        "ALTER TABLE questions ADD COLUMN source TEXT NOT NULL DEFAULT 'ai'");
  }

  /// DB v7: c_questions[106] — `printf("%d %d %d", i, i++, i)` 는 C 표준상
  /// 미정의 동작이라 컴파일러마다 출력이 다르고(clang 실측 '5 5 6' vs 등록 정답
  /// '6 5 6'), 같은 파일 87·119번과 정반대의 평가순서를 가정해 서로 모순이었다.
  /// 잘 정의된 후위 증가 문항으로 교체한다. id 보존을 위해 UPDATE 만 한다.
  @visibleForTesting
  static Future<void> fixUndefinedBehaviorQuestion(Database db) async {
    const oldSnippet = '#include <stdio.h>\n'
        'int main() {\n'
        '    int i = 5;\n'
        '    printf("%d %d %d", i, i++, i);\n'
        '    return 0;\n'
        '}';
    await db.update(
      'questions',
      {
        'code_snippet': _c106NewSnippet,
        'answer': _c106NewAnswer,
        'explanation': _c106NewExplanation,
      },
      where: 'code_snippet = ?',
      whereArgs: [oldSnippet],
    );
  }

  static const String _c106NewSnippet = '#include <stdio.h>\n'
      'int main() {\n'
      '    int i = 5;\n'
      '    int a = i++;\n'
      '    printf("%d %d", a, i);\n'
      '    return 0;\n'
      '}';
  static const String _c106NewAnswer = '5 6';
  static const String _c106NewExplanation =
      '후위 증가(i++)는 현재 값을 먼저 사용한 뒤 1 증가시킨다. '
      'a 에는 증가 전 값 5 가 대입되고, 그 직후 i 는 6 이 된다. 출력: 5 6.';

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
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
        frequency_weight REAL DEFAULT 0.5,
        source TEXT NOT NULL DEFAULT 'ai'
      )
    ''');

    await db.execute('''
      CREATE TABLE answer_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        is_correct INTEGER NOT NULL,
        user_answer TEXT NOT NULL,
        answered_at TEXT NOT NULL,
        time_spent_seconds INTEGER DEFAULT 0,
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE spaced_repetition (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL UNIQUE,
        stage INTEGER DEFAULT 0,
        next_review_at TEXT NOT NULL,
        consecutive_correct INTEGER DEFAULT 0,
        last_reviewed_at TEXT,
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');

    // 인덱스
    await db.execute(
        'CREATE INDEX idx_answer_records_question ON answer_records(question_id)');
    await db.execute(
        'CREATE INDEX idx_spaced_repetition_next ON spaced_repetition(next_review_at)');

    // 14일 플랜 테이블
    await createStudyPlanTables(db);

    // 북마크 테이블
    await _createBookmarkTable(db);

    // 모바일에서만 DB에 시드 데이터 삽입 (웹은 JSON 직접 로드)
    if (!kIsWeb) {
      var seedFailed = false;
      for (final file in _questionAssetFiles) {
        try {
          final jsonStr = await rootBundle.loadString(file);
          final List<dynamic> items = json.decode(jsonStr);
          final batch = db.batch();
          for (final item in items) {
            batch.execute(
              'INSERT INTO questions (year, round, subject, question_type, question_text, code_snippet, code_language, answer, explanation, difficulty, frequency_weight, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [item['year'], item['round'], item['subject'], item['questionType'], item['questionText'], item['codeSnippet'], item['codeLanguage'], item['answer'], item['explanation'], item['difficulty'] ?? 3, (item['frequencyWeight'] ?? 0.5), item['source'] ?? 'ai'],
            );
          }
          await batch.commit(noResult: true);
        } catch (e) {
          seedFailed = true;
          debugPrint('시드 로드 실패 ($file): $e');
        }
      }

      // 전부 심었으면 리비전을 기록해 직후의 리비전 검사가 1000문항 동기화를
      // 한 번 더 돌지 않게 한다 (신규 설치 첫 실행이 두 배로 느려지던 원인).
      // 일부라도 실패했으면 기록하지 않는다 — 그래야 리비전 검사가 빠진
      // 문항을 INSERT 로 메꾼다.
      if (!seedFailed) {
        try {
          await _writeRevision(db);
        } catch (e) {
          debugPrint('리비전 기록 실패 (동기화 1회 중복될 뿐): $e');
        }
      }
    }
  }

  /// 현재 코드의 문제 데이터 리비전을 기기에 기록한다.
  static Future<void> _writeRevision(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS $_metaTable (key TEXT PRIMARY KEY, value TEXT)');
    await db.insert(
      _metaTable,
      {'key': _metaKeyRevision, 'value': '$questionDataRevision'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 문항 식별 키. 본문과 코드가 모두 같아야 같은 문항으로 본다.
  ///
  /// 구분자로 본문에 나올 수 없는 NUL 문자를 쓴다. 공백이나 개행을 쓰면
  /// "본문 A + 코드 B" 와 "본문 A B + 코드 없음" 이 같은 키가 될 수 있다.
  /// (소스에 raw NUL 을 넣으면 파일이 바이너리로 취급되므로 반드시 이스케이프로 쓸 것)
  static String _questionKey(String? questionText, String? codeSnippet) =>
      '${questionText ?? ''}\u0000${codeSnippet ?? ''}';

  /// 다음 복습 예정 시각과 그 시점까지 쌓이는 대기 건수.
  /// 복습 알림을 예약하는 데 쓴다. 복습 대상이 없으면 null.
  Future<({DateTime dueAt, int count})?> getNextReviewSchedule() async {
    if (kIsWeb) return null;
    final db = await database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    // 1) 이미 기한이 지난(밀린) 복습이 있는지 먼저 본다.
    //
    // 예전에는 MIN(next_review_at) 을 그대로 알림 시각으로 썼다. 그런데 복습이
    // 하나라도 밀리면(= 지극히 정상적인 상황) MIN 이 과거 시각이 되고,
    // scheduleReviewReminder 는 기존 예약을 취소한 뒤 "과거라서" 아무것도 잡지
    // 않는다. 결과적으로 첫 연체 순간부터 복습 알림이 영구 정지됐다.
    final overdueRows = await db.rawQuery(
      'SELECT COUNT(*) FROM spaced_repetition WHERE next_review_at <= ?',
      [nowIso],
    );
    final overdue = _firstInt(overdueRows);
    if (overdue > 0) {
      // 밀린 게 있으면 곧바로 알린다. 지금 즉시 띄우면 방금 문제를 푼 유저에게
      // 알림이 겹치므로 잠깐 뒤로 미룬다.
      return (dueAt: now.add(_overdueReminderDelay), count: overdue);
    }

    // 2) 밀린 게 없으면 앞으로 가장 빨리 도래하는 복습 시각을 잡는다.
    final futureRows = await db.rawQuery(
      'SELECT MIN(next_review_at) AS next FROM spaced_repetition '
      'WHERE next_review_at > ?',
      [nowIso],
    );
    final raw = futureRows.isEmpty ? null : futureRows.first['next'] as String?;
    if (raw == null) return null;

    final dueAt = DateTime.tryParse(raw);
    if (dueAt == null) return null;

    // 30분 유예는 이 분기에도 적용한다. stage 0(1분) 문제를 방금 틀린 유저는
    // 아직 해설을 읽거나 다음 문제를 푸는 중이다 — 1분 뒤 헤드업 알림이
    // 학습 화면 위로 뜨면 overdue 분기가 막으려던 바로 그 상황이 재현된다.
    final minDue = now.add(_overdueReminderDelay);
    final effectiveDue = dueAt.isBefore(minDue) ? minDue : dueAt;

    // 그 시각까지 기한이 도래하는 문항 수 (알림 문구에 쓴다).
    // 예전에는 MIN 값 자신만 세어 항상 1 이 나왔다.
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) FROM spaced_repetition WHERE next_review_at <= ?',
      [effectiveDue.toIso8601String()],
    );
    return (dueAt: effectiveDue, count: _firstInt(countRows));
  }

  /// 밀린 복습을 알릴 때 두는 여유. 방금 문제를 푼 직후 알림이 겹치지 않게 한다.
  static const Duration _overdueReminderDelay = Duration(minutes: 30);

  /// 회차별 문항 수 (연도·회차 내림차순).
  ///
  /// **출처(source)까지 묶음 단위에 넣는다.** 같은 "2026년 2회" 안에 복원 기출과
  /// AI 예상문제가 함께 있는데, 합쳐서 세면 화면에서 둘이 섞여버린다.
  Future<List<({int year, int round, String source, int count})>>
      getRoundSummary() async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      final map = <String, int>{};
      for (final q in all) {
        map['${q.year}|${q.round}|${q.source}'] =
            (map['${q.year}|${q.round}|${q.source}'] ?? 0) + 1;
      }
      final out = map.entries.map((e) {
        final p = e.key.split('|');
        return (
          year: int.parse(p[0]),
          round: int.parse(p[1]),
          source: p[2],
          count: e.value
        );
      }).toList();
      out.sort(_byRoundDesc);
      return out;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT year, round, source, COUNT(*) AS cnt FROM questions '
      'GROUP BY year, round, source ORDER BY year DESC, round DESC',
    );
    final out = rows
        .map((r) => (
              year: r['year'] as int,
              round: r['round'] as int,
              source: (r['source'] as String?) ?? Question.sourceAi,
              count: (r['cnt'] as int?) ?? 0,
            ))
        .toList();
    out.sort(_byRoundDesc);
    return out;
  }

  /// 최신 연도·회차 먼저, 같은 회차 안에서는 복원 기출을 앞에 둔다.
  static int _byRoundDesc(
      ({int year, int round, String source, int count}) a,
      ({int year, int round, String source, int count}) b) {
    if (a.year != b.year) return b.year.compareTo(a.year);
    if (a.round != b.round) return b.round.compareTo(a.round);
    if (a.source == b.source) return 0;
    return a.source == Question.sourceRestored ? -1 : 1;
  }

  /// 특정 회차의 문항. [source] 를 주면 그 출처의 문항만 돌려준다.
  Future<List<Question>> getQuestionsByRound(int year, int round,
      {String? source}) async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      return all
          .where((q) =>
              q.year == year &&
              q.round == round &&
              (source == null || q.source == source))
          .toList();
    }
    final db = await database;
    final maps = await db.query(
      'questions',
      where: source == null
          ? 'year = ? AND round = ?'
          : 'year = ? AND round = ? AND source = ?',
      whereArgs: source == null ? [year, round] : [year, round, source],
      orderBy: 'id ASC',
    );
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  /// 서로 다른 문제를 몇 개 풀었는지 (중복 제거).
  /// 완료율 계산에 총 풀이 수를 쓰면 같은 문제를 여러 번 풀 때마다 진도가 오른다.
  Future<int> getUniqueSolvedCount() async {
    if (kIsWeb) return 0;
    final db = await database;
    final rows = await db
        .rawQuery('SELECT COUNT(DISTINCT question_id) FROM answer_records');
    return _firstInt(rows);
  }

  /// 에셋 JSON 기준으로 questions 테이블 내용을 동기화한다.
  ///
  /// 문제 데이터는 `_onCreate` 에서 최초 설치 때 1회만 삽입된다. 그래서 정답 오류를
  /// 고치거나 문항을 추가해도 **기존 유저에게는 영원히 반영되지 않았다.**
  ///
  /// id 를 보존해야 한다. answer_records / bookmarks / spaced_repetition 이 question_id 로
  /// 참조하고 있어서, DELETE 후 재삽입하면 유저의 학습 이력이 엉뚱한 문제에 붙는다.
  /// 따라서 문제 본문+코드로 매칭해 내용만 UPDATE 하고, 없는 문항만 INSERT 한다.
  ///
  /// ⚠️ **questionText / codeSnippet 자체를 고치면 안 된다.** 이 둘이 매칭 키라서
  /// 본문 오타를 고치면 옛 행은 방치되고 새 행이 INSERT 되어 문항이 영구 중복된다
  /// (삭제 경로 없음). 본문을 고쳐야 하면 여기가 아니라 **DB 버전을 올리고
  /// runMigrations 에 옛 본문 → 새 본문 UPDATE 마이그레이션을 추가**할 것.
  /// 정답·해설·난이도 수정은 자유 (리비전만 올리면 됨).
  ///
  /// 일부 파일이라도 실패하면 예외를 던진다. 삼키면 호출자가 성공으로 보고
  /// 리비전을 기록해, 이 기기에서 해당 리비전의 수정분이 영영 재시도되지 않는다.
  @visibleForTesting
  static Future<void> syncQuestionsFromAssets(Database db) async {
    // 기존 문항을 (본문 + 코드) 키로 색인
    final existing = <String, bool>{};
    for (final row
        in await db.query('questions', columns: ['question_text', 'code_snippet'])) {
      existing[_questionKey(
              row['question_text'] as String?, row['code_snippet'] as String?)] =
          true;
    }

    final failedFiles = <String>[];
    for (final file in _questionAssetFiles) {
      try {
        final jsonStr = await rootBundle.loadString(file);
        final List<dynamic> items = json.decode(jsonStr);
        final batch = db.batch();

        for (final item in items) {
          final text = item['questionText'];
          final code = item['codeSnippet'];
          final key = _questionKey(text as String?, code as String?);

          if (existing.containsKey(key)) {
            // 정답·해설·난이도만 갱신. id 는 건드리지 않는다.
            batch.rawUpdate(
              'UPDATE questions SET answer = ?, explanation = ?, difficulty = ?, '
              'frequency_weight = ?, source = ? '
              "WHERE question_text = ? AND IFNULL(code_snippet, '') = IFNULL(?, '')",
              [
                item['answer'],
                item['explanation'],
                item['difficulty'] ?? 3,
                item['frequencyWeight'] ?? 0.5,
                item['source'] ?? 'ai',
                text,
                code,
              ],
            );
          } else {
            batch.execute(
              'INSERT INTO questions (year, round, subject, question_type, question_text, code_snippet, code_language, answer, explanation, difficulty, frequency_weight, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                item['year'],
                item['round'],
                item['subject'],
                item['questionType'],
                text,
                code,
                item['codeLanguage'],
                item['answer'],
                item['explanation'],
                item['difficulty'] ?? 3,
                item['frequencyWeight'] ?? 0.5,
                item['source'] ?? 'ai',
              ],
            );
          }
        }
        await batch.commit(noResult: true);
      } catch (e) {
        // 나머지 파일은 계속 진행한다 — 성공분만큼은 반영해두는 쪽이 낫다.
        failedFiles.add(file);
        debugPrint('문제 동기화 실패 ($file): $e');
      }
    }

    if (failedFiles.isNotEmpty) {
      throw StateError('문제 동기화 실패: ${failedFiles.join(', ')}');
    }
  }

  static Future<void> _createBookmarkTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        FOREIGN KEY (question_id) REFERENCES questions(id)
      )
    ''');
  }

  Future<bool> isBookmarked(int questionId) async {
    final db = await database;
    final result = await db.query(
      'bookmarks',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    return result.isNotEmpty;
  }

  Future<void> toggleBookmark(int questionId) async {
    final db = await database;
    final existing = await db.query(
      'bookmarks',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    if (existing.isNotEmpty) {
      await db.delete('bookmarks',
          where: 'question_id = ?', whereArgs: [questionId]);
    } else {
      await db.insert('bookmarks', {
        'question_id': questionId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Question>> getBookmarkedQuestions() async {
    final db = await database;

    // 웹은 questions 테이블을 시딩하지 않는다(_onCreate 가 !kIsWeb 조건).
    // 그래서 JOIN 하면 북마크가 있어도 항상 0건이 나온다.
    // id 는 _loadFromJson 이 삽입 순서와 동일하게 매기므로 그것으로 이어붙인다.
    if (kIsWeb) {
      final rows = await db.query('bookmarks',
          columns: ['question_id'], orderBy: 'created_at DESC');
      final byId = await _questionsById();
      return rows
          .map((r) => byId[r['question_id'] as int?])
          .whereType<Question>()
          .toList();
    }

    final maps = await db.rawQuery('''
      SELECT q.* FROM questions q
      INNER JOIN bookmarks b ON q.id = b.question_id
      ORDER BY b.created_at DESC
    ''');
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  /// 웹 전용 보조: JSON 문제를 id 로 찾을 수 있게 색인한다.
  Future<Map<int?, Question>> _questionsById() async {
    final all = await _loadFromJson();
    return {for (final q in all) q.id: q};
  }

  Future<int> getBookmarkCount() async {
    final db = await database;
    return _firstInt(await db.rawQuery('SELECT COUNT(*) FROM bookmarks'));
  }

  /// study_plan 에 plan_type 컬럼을 보장한다. **반드시 멱등이어야 한다.**
  ///
  /// createStudyPlanTables 는 이미 plan_type 을 포함한 스키마로 테이블을 만든다.
  /// 그래서 DB v1·v2 유저는 onUpgrade 에서 테이블이 새로 생성된 뒤 이 함수가 호출되어
  /// 무조건 ALTER 를 때리면 "duplicate column name" 예외가 난다. onUpgrade 에서 던진
  /// 예외는 openDatabase 전체를 실패시키므로, 그 유저의 DB 는 영원히 열리지 않는다.
  /// (v1.5.4 이전까지 실제로 그랬다.)
  @visibleForTesting
  static Future<void> ensurePlanTypeColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(study_plan)');

    // 테이블 자체가 없으면 최신 스키마로 만든다 (plan_type 포함).
    if (columns.isEmpty) {
      await createStudyPlanTables(db);
      return;
    }

    final hasPlanType = columns.any((c) => c['name'] == 'plan_type');
    if (hasPlanType) return;

    await db.execute(
        "ALTER TABLE study_plan ADD COLUMN plan_type TEXT DEFAULT '14day'");
  }

  @visibleForTesting
  static Future<void> createStudyPlanTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        current_day INTEGER DEFAULT 1,
        plan_type TEXT DEFAULT '14day'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        completed INTEGER DEFAULT 0,
        completed_at TEXT,
        questions_solved INTEGER DEFAULT 0,
        questions_correct INTEGER DEFAULT 0,
        FOREIGN KEY (plan_id) REFERENCES study_plan(id)
      )
    ''');
  }

  // === Questions CRUD ===

  Future<List<Question>> getAllQuestions() async {
    if (kIsWeb) return _loadFromJson();
    final db = await database;
    final maps = await db.query('questions');
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  Future<List<Question>> getRandomQuestions(int limit) async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      all.shuffle();
      return all.take(limit).toList();
    }
    final db = await database;
    final maps = await db.query('questions', orderBy: 'RANDOM()', limit: limit);
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  // 웹용: JSON에서 직접 문제 로드 (DB 거치지 않음)
  static List<Question>? _jsonCache;
  Future<List<Question>> _loadFromJson() async {
    if (_jsonCache != null) return List.from(_jsonCache!);
    final all = <Question>[];
    int id = 1;
    // 모바일 시딩(_onCreate)과 반드시 같은 순서여야 id 가 일치한다.
    for (final file in _questionAssetFiles) {
      try {
        final jsonStr = await rootBundle.loadString(file);
        final List<dynamic> items = json.decode(jsonStr);
        for (final item in items) {
          all.add(Question(
            id: id++,
            year: item['year'] as int,
            round: item['round'] as int,
            subject: item['subject'] as String,
            questionType: item['questionType'] as String,
            questionText: item['questionText'] as String,
            codeSnippet: item['codeSnippet'] as String?,
            codeLanguage: item['codeLanguage'] as String?,
            answer: item['answer'] as String,
            explanation: item['explanation'] as String,
            difficulty: item['difficulty'] as int? ?? 3,
            frequencyWeight: (item['frequencyWeight'] as num?)?.toDouble() ?? 0.5,
            source: item['source'] as String? ?? Question.sourceAi,
          ));
        }
      } catch (e) {
        debugPrint('JSON 로드 실패 ($file): $e');
      }
    }
    _jsonCache = all;
    return List.from(all);
  }

  Future<List<Question>> getQuestionsByType(String type, {int limit = 50}) async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      final filtered = all.where((q) => q.questionType == type).toList();
      filtered.shuffle();
      return filtered.take(limit).toList();
    }
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'question_type = ?',
      whereArgs: [type],
      orderBy: 'RANDOM()',
      limit: limit,
    );
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  /// 유형 + 난이도 필터링 (난이도 범위: minDiff~maxDiff)
  Future<List<Question>> getQuestionsByTypeAndDifficulty(
    String? type, {
    int? minDifficulty,
    int? maxDifficulty,
    int limit = 20,
  }) async {
    if (kIsWeb) {
      var all = await _loadFromJson();
      if (type != null) {
        all = all.where((q) => q.questionType == type).toList();
      }
      if (minDifficulty != null) {
        all = all.where((q) => q.difficulty >= minDifficulty).toList();
      }
      if (maxDifficulty != null) {
        all = all.where((q) => q.difficulty <= maxDifficulty).toList();
      }
      all.shuffle();
      return all.take(limit).toList();
    }
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];
    if (type != null) {
      whereParts.add('question_type = ?');
      whereArgs.add(type);
    }
    if (minDifficulty != null) {
      whereParts.add('difficulty >= ?');
      whereArgs.add(minDifficulty);
    }
    if (maxDifficulty != null) {
      whereParts.add('difficulty <= ?');
      whereArgs.add(maxDifficulty);
    }
    final maps = await db.query(
      'questions',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'RANDOM()',
      limit: limit,
    );
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  Future<Question?> getQuestionById(int id) async {
    final db = await database;
    final maps = await db.query('questions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Question.fromMap(maps.first);
  }

  // === Answer Records ===

  Future<void> insertAnswerRecord(AnswerRecord record) async {
    final db = await database;
    final m = record.toMap()..remove('id');
    await db.execute(
      'INSERT INTO answer_records (question_id, is_correct, user_answer, answered_at, time_spent_seconds) VALUES (?, ?, ?, ?, ?)',
      [m['question_id'], m['is_correct'], m['user_answer'], m['answered_at'], m['time_spent_seconds']],
    );
  }

  /// 전체 문제의 오답률을 한 번의 쿼리로 계산
  Future<Map<int, double>> getAllErrorRates() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT question_id,
             COUNT(*) as total,
             SUM(CASE WHEN is_correct = 0 THEN 1 ELSE 0 END) as wrong
      FROM answer_records
      GROUP BY question_id
    ''');
    final map = <int, double>{};
    for (final row in results) {
      final qid = row['question_id'];
      final total = row['total'];
      final wrong = row['wrong'];
      final qidInt = qid is int ? qid : (qid as num).toInt();
      final totalInt = total is int ? total : (total as num).toInt();
      final wrongInt = wrong is int ? wrong : (wrong as num).toInt();
      map[qidInt] = totalInt > 0 ? wrongInt / totalInt : 0.0;
    }
    return map;
  }

  Future<List<AnswerRecord>> getRecordsByQuestion(int questionId) async {
    final db = await database;
    final maps = await db.query(
      'answer_records',
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'answered_at DESC',
    );
    return maps.map((m) => AnswerRecord.fromMap(m)).toList();
  }

  int _firstInt(List<Map<String, dynamic>> result) {
    if (result.isEmpty) return 0;
    final val = result.first.values.first;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return 0;
  }

  Future<Map<String, dynamic>> getOverallStats() async {
    final db = await database;

    final total = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM answer_records'));
    final correct = _firstInt(await db
        .rawQuery('SELECT COUNT(*) FROM answer_records WHERE is_correct = 1'));

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayTotal = _firstInt(await db.rawQuery(
        'SELECT COUNT(*) FROM answer_records WHERE answered_at LIKE ?',
        ['$today%']));
    final todayCorrect = _firstInt(await db.rawQuery(
        'SELECT COUNT(*) FROM answer_records WHERE answered_at LIKE ? AND is_correct = 1',
        ['$today%']));

    return {
      'total': total,
      'correct': correct,
      'todayTotal': todayTotal,
      'todayCorrect': todayCorrect,
    };
  }

  static const _allowedFields = {'subject', 'question_type'};

  Future<Map<String, double>> getAccuracyByField(String field) async {
    if (!_allowedFields.contains(field)) {
      throw ArgumentError('Invalid field: $field');
    }
    final db = await database;
    final results = await db.rawQuery('''
      SELECT q.$field,
             COUNT(*) as total,
             SUM(CASE WHEN ar.is_correct = 1 THEN 1 ELSE 0 END) as correct
      FROM answer_records ar
      JOIN questions q ON ar.question_id = q.id
      GROUP BY q.$field
    ''');

    final map = <String, double>{};
    for (final row in results) {
      final key = row[field] as String;
      final total = row['total'] is int ? row['total'] as int : (row['total'] as num).toInt();
      final correct = row['correct'] is int ? row['correct'] as int : ((row['correct'] ?? 0) as num).toInt();
      map[key] = total > 0 ? (correct / total) * 100 : 0;
    }
    return map;
  }

  Future<Map<String, int>> getSolvedCountByField(String field) async {
    if (!_allowedFields.contains(field)) return {};
    final db = await database;
    final results = await db.rawQuery('''
      SELECT q.$field, COUNT(*) as total
      FROM answer_records ar
      JOIN questions q ON ar.question_id = q.id
      GROUP BY q.$field
    ''');

    final map = <String, int>{};
    for (final row in results) {
      final key = row[field] as String;
      final total = row['total'];
      map[key] = total is int ? total : (total as num).toInt();
    }
    return map;
  }

  Future<Map<int, double>> getAccuracyByDifficulty() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT q.difficulty,
             COUNT(*) as total,
             SUM(CASE WHEN ar.is_correct = 1 THEN 1 ELSE 0 END) as correct
      FROM answer_records ar
      JOIN questions q ON ar.question_id = q.id
      GROUP BY q.difficulty
    ''');

    final map = <int, double>{};
    for (final row in results) {
      final diff = row['difficulty'];
      final diffInt = diff is int ? diff : (diff as num).toInt();
      final total = row['total'];
      final correct = row['correct'];
      final totalInt = total is int ? total : (total as num).toInt();
      final correctInt = correct is int ? correct : (correct as num).toInt();
      map[diffInt] = totalInt > 0 ? (correctInt / totalInt) * 100 : 0;
    }
    return map;
  }

  Future<int> getTotalQuestionCount() async {
    if (kIsWeb) return (await _loadFromJson()).length;
    final db = await database;
    return _firstInt(await db.rawQuery('SELECT COUNT(*) FROM questions'));
  }

  Future<int> getStreakDays() async {
    final db = await database;
    // Get distinct dates with answer records, ordered descending
    final results = await db.rawQuery('''
      SELECT DISTINCT substr(answered_at, 1, 10) as day
      FROM answer_records
      ORDER BY day DESC
    ''');

    if (results.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();
    DateTime check = DateTime(today.year, today.month, today.day);

    // 첫 번째 기록이 어제인 경우도 스트릭에 포함
    final firstDayStr = results.first['day'] as String;
    final firstParts = firstDayStr.split('-');
    if (firstParts.length == 3) {
      final firstDate = DateTime(
        int.parse(firstParts[0]),
        int.parse(firstParts[1]),
        int.parse(firstParts[2]),
      );
      final yesterday = check.subtract(const Duration(days: 1));
      if (firstDate == yesterday) {
        check = yesterday;
      }
    }

    for (final row in results) {
      final dayStr = row['day'] as String;
      final parts = dayStr.split('-');
      if (parts.length != 3) break;
      final rowDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      if (rowDate == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<Map<String, dynamic>>> getLast7DaysStats() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT substr(answered_at, 1, 10) as day,
             COUNT(*) as total,
             SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct
      FROM answer_records
      WHERE answered_at >= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [DateTime.now().subtract(const Duration(days: 6)).toIso8601String().substring(0, 10)]);
    return results;
  }

  // === Spaced Repetition ===

  Future<void> upsertSpacedRepetition({
    required int questionId,
    required int stage,
    required DateTime nextReviewAt,
    required int consecutiveCorrect,
  }) async {
    final db = await database;
    await db.execute(
      'INSERT OR REPLACE INTO spaced_repetition (question_id, stage, next_review_at, consecutive_correct, last_reviewed_at) VALUES (?, ?, ?, ?, ?)',
      [questionId, stage, nextReviewAt.toIso8601String(), consecutiveCorrect, DateTime.now().toIso8601String()],
    );
  }

  /// 복습 큐에서 제거한다 (졸업). answer_records 의 풀이 이력은 남는다.
  Future<void> deleteSpacedRepetition(int questionId) async {
    final db = await database;
    await db.delete('spaced_repetition',
        where: 'question_id = ?', whereArgs: [questionId]);
  }

  Future<List<Map<String, dynamic>>> getDueReviews() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // 웹은 questions 테이블이 비어 있어 JOIN 이 항상 0건이다 (오답노트가 늘 빈 상태).
    if (kIsWeb) {
      final rows = await db.query('spaced_repetition',
          where: 'next_review_at <= ?',
          whereArgs: [now],
          orderBy: 'next_review_at ASC');
      final byId = await _questionsById();
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final q = byId[r['question_id'] as int?];
        if (q == null) continue;
        out.add({
          ...q.toMap(),
          'stage': r['stage'],
          'next_review_at': r['next_review_at'],
          'consecutive_correct': r['consecutive_correct'],
          'last_reviewed_at': r['last_reviewed_at'],
        });
      }
      return out;
    }

    return await db.rawQuery('''
      SELECT q.id, q.year, q.round, q.subject, q.question_type,
             q.question_text, q.code_snippet, q.code_language,
             q.answer, q.explanation, q.difficulty, q.frequency_weight,
             sr.stage, sr.next_review_at, sr.consecutive_correct, sr.last_reviewed_at
      FROM spaced_repetition sr
      JOIN questions q ON sr.question_id = q.id
      WHERE sr.next_review_at <= ?
      ORDER BY sr.next_review_at ASC
    ''', [now]);
  }

  Future<Map<String, dynamic>?> getSpacedRepetition(int questionId) async {
    final db = await database;
    final maps = await db.query(
      'spaced_repetition',
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    return maps.isEmpty ? null : maps.first;
  }
}
