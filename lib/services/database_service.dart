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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConfig.dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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

    // 시드 데이터 삽입
    for (final q in QuestionSeedData.questions) {
      await db.insert('questions', q.toMap()..remove('id'));
    }
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
    await db.insert('answer_records', record.toMap()..remove('id'));
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

  Future<Map<String, dynamic>> getOverallStats() async {
    final db = await database;

    final total = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM answer_records')) ??
        0;
    final correct = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM answer_records WHERE is_correct = 1')) ??
        0;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayTotal = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM answer_records WHERE answered_at LIKE ?',
            ['$today%'])) ??
        0;
    final todayCorrect = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM answer_records WHERE answered_at LIKE ? AND is_correct = 1',
            ['$today%'])) ??
        0;

    return {
      'total': total,
      'correct': correct,
      'todayTotal': todayTotal,
      'todayCorrect': todayCorrect,
    };
  }

  Future<Map<String, double>> getAccuracyByField(String field) async {
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

  // === Spaced Repetition ===

  Future<void> upsertSpacedRepetition({
    required int questionId,
    required int stage,
    required DateTime nextReviewAt,
    required int consecutiveCorrect,
  }) async {
    final db = await database;
    await db.insert(
      'spaced_repetition',
      {
        'question_id': questionId,
        'stage': stage,
        'next_review_at': nextReviewAt.toIso8601String(),
        'consecutive_correct': consecutiveCorrect,
        'last_reviewed_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDueReviews() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.rawQuery('''
      SELECT sr.*, q.*
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
