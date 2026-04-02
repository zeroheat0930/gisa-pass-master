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

    // 모바일에서만 DB에 시드 데이터 삽입 (웹은 JSON 직접 로드)
    if (!kIsWeb) {
      const files = [
        'assets/questions/c_questions.json',
        'assets/questions/java_questions.json',
        'assets/questions/python_questions.json',
        'assets/questions/sql_questions.json',
        'assets/questions/short_answer_questions.json',
      ];
      for (final file in files) {
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
    final files = [
      'assets/questions/c_questions.json',
      'assets/questions/java_questions.json',
      'assets/questions/python_questions.json',
      'assets/questions/sql_questions.json',
      'assets/questions/short_answer_questions.json',
    ];
    final all = <Question>[];
    int id = 1;
    for (final file in files) {
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

  Future<List<Question>> getQuestionsByType(String type) async {
    if (kIsWeb) {
      final all = await _loadFromJson();
      return all.where((q) => q.questionType == type).toList();
    }
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
