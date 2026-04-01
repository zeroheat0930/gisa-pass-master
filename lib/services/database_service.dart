import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config.dart';
import '../models/question.dart';
import '../models/answer_record.dart';
import 'question_seed_data.dart';

class DatabaseService {
  static Database? _database;

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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS spaced_repetition');
          await db.execute('DROP TABLE IF EXISTS answer_records');
          await db.execute('DROP TABLE IF EXISTS questions');
          await _onCreate(db, newVersion);
        }
      },
    );
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

    // JSON 에셋에서 시드 데이터 로드 및 삽입 (배치로 고속 처리)
    final questions = await QuestionSeedData.loadAll();
    final batch = db.batch();
    for (final q in questions) {
      final m = q.toMap()..remove('id');
      batch.execute(
        'INSERT INTO questions (year, round, subject, question_type, question_text, code_snippet, code_language, answer, explanation, difficulty, frequency_weight) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [m['year'], m['round'], m['subject'], m['question_type'], m['question_text'], m['code_snippet'], m['code_language'], m['answer'], m['explanation'], m['difficulty'], m['frequency_weight']],
      );
    }
    await batch.commit(noResult: true);
  }

  // === Questions CRUD ===

  Future<List<Question>> getAllQuestions() async {
    final db = await database;
    final maps = await db.query('questions');
    return maps.map((m) => Question.fromMap(m)).toList();
  }

  Future<List<Question>> getQuestionsByType(String type) async {
    final db = await database;
    final maps = await db.query(
      'questions',
      where: 'question_type = ?',
      whereArgs: [type],
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
    assert(_allowedFields.contains(field), 'Invalid field: $field');
    if (!_allowedFields.contains(field)) return {};
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
      final total = row['total'] as int;
      final correct = row['correct'] as int;
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
      WHERE answered_at >= date('now', '-6 days')
      GROUP BY day
      ORDER BY day ASC
    ''');
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
