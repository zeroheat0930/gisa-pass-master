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

  /// 문제 데이터 에셋. 최초 시딩(_onCreate)과 갱신(syncQuestionsFromAssets)이
  /// 같은 목록을 봐야 하므로 한 곳에서만 정의한다.
  static const List<String> _questionAssetFiles = [
    'assets/questions/c_questions.json',
    'assets/questions/java_questions.json',
    'assets/questions/python_questions.json',
    'assets/questions/sql_questions.json',
    'assets/questions/short_answer_questions.json',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final String path;
    if (kIsWeb) {
      path = AppConfig.dbName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, AppConfig.dbName);
    }

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: runMigrations,
    );
  }

  /// 버전 업그레이드 마이그레이션 (테스트 가능한 진입점).
  ///
  /// 예전에는 이 로직이 onUpgrade 클로저 안에 갇혀 있어서, 개별 마이그레이션
  /// 함수는 테스트하면서도 **그것이 실제로 연결되어 있는지는 아무도 검증하지
  /// 못했다.** 연결을 끊어도 테스트가 전부 통과하는 상태였다.
  @visibleForTesting
  Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
    if (oldVersion < 6) {
      // 문제 데이터는 최초 설치 때 1회만 시딩되므로, 정답 오류를 고쳐도
      // 기존 유저에게는 영원히 반영되지 않았다. 에셋 기준으로 내용을 동기화한다.
      await syncQuestionsFromAssets(db);
    }
  }

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
        frequency_weight REAL DEFAULT 0.5
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
      for (final file in _questionAssetFiles) {
        try {
          final jsonStr = await rootBundle.loadString(file);
          final List<dynamic> items = json.decode(jsonStr);
          final batch = db.batch();
          for (final item in items) {
            batch.execute(
              'INSERT INTO questions (year, round, subject, question_type, question_text, code_snippet, code_language, answer, explanation, difficulty, frequency_weight) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [item['year'], item['round'], item['subject'], item['questionType'], item['questionText'], item['codeSnippet'], item['codeLanguage'], item['answer'], item['explanation'], item['difficulty'] ?? 3, (item['frequencyWeight'] ?? 0.5)],
            );
          }
          await batch.commit(noResult: true);
        } catch (e) {
          debugPrint('시드 로드 실패 ($file): $e');
        }
      }
    }
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
    final rows = await db.rawQuery(
      'SELECT MIN(next_review_at) AS next FROM spaced_repetition',
    );
    final raw = rows.isEmpty ? null : rows.first['next'] as String?;
    if (raw == null) return null;

    final dueAt = DateTime.tryParse(raw);
    if (dueAt == null) return null;

    // 그 시각까지 복습 기한이 도래하는 문항 수
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) FROM spaced_repetition WHERE next_review_at <= ?',
      [raw],
    );
    return (dueAt: dueAt, count: _firstInt(countRows));
  }

  /// 회차별 문항 수 (연도·회차 내림차순).
  /// 회차별 문제집 화면에서 목록을 만드는 데 쓴다.
  Future<List<({int year, int round, int count})>> getRoundSummary() async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      final map = <String, int>{};
      for (final q in all) {
        final key = '${q.year}-${q.round}';
        map[key] = (map[key] ?? 0) + 1;
      }
      final out = map.entries.map((e) {
        final parts = e.key.split('-');
        return (
          year: int.parse(parts[0]),
          round: int.parse(parts[1]),
          count: e.value
        );
      }).toList();
      out.sort((a, b) => a.year != b.year
          ? b.year.compareTo(a.year)
          : b.round.compareTo(a.round));
      return out;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT year, round, COUNT(*) AS cnt FROM questions '
      'GROUP BY year, round ORDER BY year DESC, round DESC',
    );
    return rows
        .map((r) => (
              year: r['year'] as int,
              round: r['round'] as int,
              count: (r['cnt'] as int?) ?? 0,
            ))
        .toList();
  }

  /// 특정 회차의 문항 전부
  Future<List<Question>> getQuestionsByRound(int year, int round) async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      return all.where((q) => q.year == year && q.round == round).toList();
    }
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'year = ? AND round = ?',
      whereArgs: [year, round],
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
              'frequency_weight = ? '
              "WHERE question_text = ? AND IFNULL(code_snippet, '') = IFNULL(?, '')",
              [
                item['answer'],
                item['explanation'],
                item['difficulty'] ?? 3,
                item['frequencyWeight'] ?? 0.5,
                text,
                code,
              ],
            );
          } else {
            batch.execute(
              'INSERT INTO questions (year, round, subject, question_type, question_text, code_snippet, code_language, answer, explanation, difficulty, frequency_weight) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
              ],
            );
          }
        }
        await batch.commit(noResult: true);
      } catch (e) {
        debugPrint('문제 동기화 실패 ($file): $e');
      }
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
