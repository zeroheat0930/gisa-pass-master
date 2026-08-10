import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gisa_pass_master/models/answer_record.dart';
import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';

/// **배선(wiring) 테스트.**
///
/// 이 앱의 반복 실패 패턴은 "부품은 멀쩡한데 연결이 빠진 것"이다.
/// 실제로 아래 세 수정을 통째로 되돌려도 기존 테스트 77건이 전부 통과했다.
///
///   1. 정답일 때 processAnswer 를 호출하지 않도록 되돌림  → 77건 통과
///   2. DB v6 동기화를 onUpgrade 에서 떼어냄               → 77건 통과
///   3. AI 모의고사 무료 쿼터 게이트를 제거함              → 77건 통과
///
/// 부품 단위 테스트만으로는 이 종류를 절대 잡을 수 없다. 여기서 연결을 검증한다.

// ── grep 기반 검증용: 주석을 걷어낸 소스 ────────────────────────────────────
//
// 원본 소스를 그대로 grep 하면 **주석에도 매칭**된다. 실제로 AiExamQuota.consume
// 호출을 주석 처리해 되돌려도(무료 무제한 응시) 전부 녹색이었다.
// 라인 주석을 지운 소스에서만 찾는다.
String _activeSource(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');
}

// ── 배선 확인용 스파이 ──────────────────────────────────────────────────────

class _SpyRepetition extends SpacedRepetitionService {
  _SpyRepetition(super.db);

  final List<({int questionId, bool isCorrect})> calls = [];

  @override
  Future<void> processAnswer(int questionId, bool isCorrect) async {
    calls.add((questionId: questionId, isCorrect: isCorrect));
  }
}

class _SpyDatabase extends DatabaseService {
  final List<AnswerRecord> records = [];

  /// 이 문제가 이미 복습 큐에 있는지 (정답 시 승격 경로 재현용)
  bool tracked = false;

  @override
  Future<void> insertAnswerRecord(AnswerRecord record) async {
    records.add(record);
  }

  @override
  Future<Map<String, dynamic>?> getSpacedRepetition(int questionId) async =>
      tracked ? {'stage': 1, 'consecutive_correct': 1} : null;

  @override
  Future<void> upsertSpacedRepetition({
    required int questionId,
    required int stage,
    required DateTime nextReviewAt,
    required int consecutiveCorrect,
  }) async {}
}

Question _question({int id = 42}) => Question(
      id: id,
      year: 2026,
      round: 3,
      subject: '테스트',
      questionType: 'short_answer',
      questionText: '용어를 쓰시오.',
      answer: '스택',
      explanation: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ── 1) 복습 스케줄 배선 ───────────────────────────────────────────────────
  // 정답일 때 processAnswer 를 부르지 않으면 stage 승격이 없어 오답노트가
  // 영원히 비워지지 않고 복습 간격이 1분에 고정된다.
  group('풀이 기록 → 복습 스케줄 배선', () {
    late _SpyDatabase db;
    late _SpyRepetition srs;
    late StudyProvider provider;

    setUp(() {
      db = _SpyDatabase();
      srs = _SpyRepetition(db);
      provider = StudyProvider(
        db: db,
        predictionEngine: PredictionEngine(),
        spacedRepetitionService: srs,
      );
    });

    test('정답일 때도 복습 스케줄이 갱신된다', () async {
      await provider.recordAnswer(
        question: _question(),
        userAnswer: '스택',
        isCorrect: true,
      );

      expect(srs.calls, hasLength(1),
          reason: '정답을 걸러내면 오답노트가 영원히 졸업되지 않는다');
      expect(srs.calls.single.questionId, 42);
      expect(srs.calls.single.isCorrect, isTrue);
    });

    test('오답일 때도 복습 스케줄이 갱신된다', () async {
      await provider.recordAnswer(
        question: _question(),
        userAnswer: '큐',
        isCorrect: false,
      );

      expect(srs.calls, hasLength(1));
      expect(srs.calls.single.isCorrect, isFalse);
    });

    test('풀이 기록이 DB에 저장된다', () async {
      await provider.recordAnswer(
        question: _question(),
        userAnswer: '스택',
        isCorrect: true,
      );

      expect(db.records, hasLength(1));
      expect(db.records.single.questionId, 42);
      expect(db.records.single.userAnswer, '스택');
    });
  });

  // ── 2) DB 마이그레이션 배선 ──────────────────────────────────────────────
  // 개별 마이그레이션 함수는 테스트하면서도, 그것이 onUpgrade 에 실제로
  // 연결되어 있는지는 아무도 확인하지 않았다.
  group('DB 업그레이드 배선', () {
    test('v5 → v6 업그레이드가 문제 데이터를 실제로 동기화한다', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      await db.execute('''
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          year INTEGER NOT NULL, round INTEGER NOT NULL,
          subject TEXT NOT NULL, question_type TEXT NOT NULL,
          question_text TEXT NOT NULL, code_snippet TEXT, code_language TEXT,
          answer TEXT NOT NULL, explanation TEXT NOT NULL,
          difficulty INTEGER DEFAULT 3, frequency_weight REAL DEFAULT 0.5
        )
      ''');

      // 구버전 유저가 들고 있던 '틀린 정답' 상태를 재현
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
        'answer': 'STALE_WRONG_ANSWER',
        'explanation': '옛 해설',
      });

      // onUpgrade 가 실제로 하는 일을 그대로 실행한다.
      await DatabaseService().runMigrations(db, 5, 6);

      final rows = await db.query('questions', where: 'id = ?', whereArgs: [id]);
      expect(rows.single['answer'], target['answer'],
          reason: 'v6 동기화가 onUpgrade 에 연결되어 있지 않으면 여기서 실패한다');
      expect(rows.single['id'], id, reason: 'id 는 보존되어야 한다');
    });

    test('v3 → v6 업그레이드도 duplicate column 없이 통과한다', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);

      await db.execute('''
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          year INTEGER NOT NULL, round INTEGER NOT NULL,
          subject TEXT NOT NULL, question_type TEXT NOT NULL,
          question_text TEXT NOT NULL, code_snippet TEXT, code_language TEXT,
          answer TEXT NOT NULL, explanation TEXT NOT NULL,
          difficulty INTEGER DEFAULT 3, frequency_weight REAL DEFAULT 0.5
        )
      ''');
      // v3 당시 스키마 (plan_type 없음)
      await db.execute('''
        CREATE TABLE study_plan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT NOT NULL, current_day INTEGER DEFAULT 1
        )
      ''');

      await expectLater(DatabaseService().runMigrations(db, 3, 6), completes);

      final cols = await db.rawQuery('PRAGMA table_info(study_plan)');
      expect(cols.any((c) => c['name'] == 'plan_type'), isTrue);
    });
  });

  // ── 3) 수익 게이트 배선 ──────────────────────────────────────────────────
  // 쿼터 클래스 자체는 테스트하면서, 화면이 그것을 실제로 물어보는지는
  // 검증하지 않았다. 게이트를 통째로 지워도 테스트가 전부 통과했다.
  group('AI 모의고사 유료 게이트 배선', () {
    String source(String path) => _activeSource(path);

    test('모의고사 진입 경로가 쿼터를 확인한다', () {
      final home = source('lib/screens/home_screen.dart');
      expect(home.contains('AiExamQuota.canStart'), isTrue,
          reason: '진입 시 무료 응시 가능 여부를 확인해야 한다 (수익 직결)');
    });

    test('다시 풀기 경로도 쿼터를 확인한다', () {
      final exam = source('lib/screens/ai_prediction_screen.dart');
      expect(exam.contains('AiExamQuota.canStart'), isTrue,
          reason: '결과 화면의 다시 풀기가 게이트를 우회하면 안 된다');
    });

    test('시험이 시작되면 쿼터를 소모한다', () {
      final exam = source('lib/screens/ai_prediction_screen.dart');
      expect(exam.contains('AiExamQuota.consume'), isTrue,
          reason: '확인만 하고 소모하지 않으면 제한이 무의미하다');
    });
  });

  // ── 4) 출제 예측 선정 ────────────────────────────────────────────────────
  // 우선순위 점수는 사실상 결정적이라, 전체를 정렬해 상위 N개를 자르면 매 세션
  // 똑같은 문제만 나오고 나머지 수백 문항이 영영 출제되지 않는다.
  group('출제 예측 세션 선정', () {
    List<Question> pool(int n) => List.generate(
          n,
          (i) => Question(
            id: i + 1,
            year: 2020 + (i % 7),
            round: 1,
            subject: '과목${i % 5}',
            questionType: ['code_reading', 'sql', 'short_answer'][i % 3],
            questionText: '문제 $i',
            answer: '답 $i',
            explanation: '',
            frequencyWeight: (i % 10) / 10,
          ),
        );

    test('세션마다 같은 문제만 반복되지 않는다', () {
      final engine = PredictionEngine();
      final questions = pool(1000);

      final a = engine.selectForSession(questions, const {}, sessionSize: 50);
      final b = engine.selectForSession(questions, const {}, sessionSize: 50);

      expect(a, hasLength(50));
      expect(b, hasLength(50));

      final idsA = a.map((q) => q.id).toSet();
      final idsB = b.map((q) => q.id).toSet();
      expect(idsA, isNot(equals(idsB)),
          reason: '두 세션이 완전히 같으면 대부분의 문항이 영영 출제되지 않는다');
    });

    test('무작위가 아니라 상위 우선순위 풀에서만 뽑는다', () {
      final engine = PredictionEngine();
      final questions = pool(1000);

      final prioritized = engine.getPrioritizedQuestions(questions, const {});
      final topPool = prioritized.take(50 * 4).map((q) => q.id).toSet();

      final selected =
          engine.selectForSession(questions, const {}, sessionSize: 50);

      for (final q in selected) {
        expect(topPool.contains(q.id), isTrue,
            reason: '예측 엔진이 고른 상위 풀 밖에서 나오면 예측이 무의미하다');
      }
    });

    test('문항이 세션 크기보다 적으면 전부 반환한다', () {
      final engine = PredictionEngine();
      final selected =
          engine.selectForSession(pool(10), const {}, sessionSize: 50);
      expect(selected, hasLength(10));
    });
  });

  // ── 5) 채점기 호출부 배선 ────────────────────────────────────────────────
  // 문제은행 채점을 단순 문자열 비교로 되돌려도 기존 테스트가 전부 통과했다.
  // 채점기 자체만 검증하고 화면이 그것을 쓰는지는 아무도 안 봤기 때문이다.
  group('채점기 호출부 배선', () {
    String source(String path) => _activeSource(path);

    const screens = [
      'lib/screens/quiz_screen.dart',
      'lib/screens/past_exam_screen.dart',
      'lib/screens/ai_prediction_screen.dart',
    ];

    test('답을 채점하는 화면은 모두 AnswerChecker 정본을 쓴다', () {
      final offenders = <String>[];
      for (final path in screens) {
        final src = source(path);
        final gradesHere = src.contains('_isCorrectList') ||
            src.contains('submitAnswer(');
        if (!gradesHere) continue;
        // quiz_screen 은 StudyProvider.submitAnswer 를 통해 채점한다.
        final usesChecker = src.contains('AnswerChecker.isCorrectFor') ||
            src.contains('provider.submitAnswer');
        if (!usesChecker) offenders.add(path);
      }
      expect(offenders, isEmpty,
          reason: '직접 문자열 비교로 되돌아간 화면: $offenders');
    });

    test('화면에 자체 정답 비교가 재등장하지 않았다', () {
      final offenders = <String>[];
      for (final path in screens) {
        final src = source(path);
        // "answer.toLowerCase() == question.answer..." 같은 직접 비교의 흔적
        if (RegExp(r'answer\s*\.toLowerCase\(\)\s*(\.trim\(\))?\s*==')
            .hasMatch(src)) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty,
          reason: '채점 로직이 화면에 복제되었다: $offenders');
    });
  });

  // ── 6) 복습 알림 배선 ────────────────────────────────────────────────────
  // 문자열 grep 으로 검증했더니 '함수 선언문 자체' 에 걸려서, 호출을 통째로
  // 지워도 전부 통과했다(QA 가 잡아냄). 실제 호출을 스파이로 검증한다.
  group('복습 알림 배선', () {
    test('복습 스케줄을 갱신하면 알림 재예약이 실제로 호출된다', () async {
      final db = _SpyDatabase();
      final srs = _SpyReschedule(db);

      await srs.processAnswer(1, false);

      expect(srs.rescheduleCalls, greaterThan(0),
          reason: '스케줄만 갱신하고 알림을 안 잡으면 유저에게 도달하지 못한다');
    });

    test('정답이어도(큐에 있는 문제면) 알림을 다시 잡는다', () async {
      final db = _SpyDatabase()..tracked = true;
      final srs = _SpyReschedule(db);

      await srs.processAnswer(1, true);

      expect(srs.rescheduleCalls, greaterThan(0));
    });

    test('Android 예약 알림 리시버가 선언되어 있다', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('ScheduledNotificationReceiver'), isTrue,
          reason: '이 선언이 없으면 Android 에서 예약 알림이 단 한 건도 발화하지 않는다');
      expect(manifest.contains('ScheduledNotificationBootReceiver'), isTrue,
          reason: '재부팅 후 예약이 복원되지 않는다');
      expect(manifest.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
    });

    test('DB 를 열 때 데이터 리비전 동기화가 호출된다', () {
      final src = _activeSource('lib/services/database_service.dart');
      // 선언문이 아니라 **호출식**을 확인한다 (await + 인자).
      expect(src.contains('await syncQuestionsIfRevisionChanged(db);'), isTrue,
          reason: '이 호출이 빠지면 v6 이후 유저에게 정답 수정이 영영 도달하지 않는다');
    });

    test('알림을 켜는 경로에 후속 재예약 훅이 물려 있다', () {
      final main = _activeSource('lib/main.dart');
      expect(main.contains('NotificationOptIn.onEnabled ='), isTrue,
          reason: '켠 직후 복습 알림을 잡지 않으면 다이얼로그가 한 약속이 안 지켜진다');
    });
  });

  // ── 7) 통계 재조회 배선 ──────────────────────────────────────────────────
  // IndexedStack 은 탭을 계속 살려두므로 initState 가 다시 돌지 않는다.
  // 이 재조회가 빠지면 문제를 풀어도 홈·통계 화면이 앱 재시작 전까지 옛 값을
  // 붙들고 있는다 — 과거 실제로 터졌던 회귀인데 어떤 테스트도 지키지 않았다.
  group('통계 재조회 배선', () {
    test('통계를 보여주는 탭으로 전환하면 다시 읽는다', () {
      final main = _activeSource('lib/main.dart');
      expect(main.contains('StatsProvider>().loadStats()'), isTrue,
          reason: '탭 전환 시 loadStats 호출이 빠지면 통계가 앱 재시작 전까지 멈춘다');
    });
  });
}

/// processAnswer 가 알림 재예약을 실제로 부르는지 세는 스파이.
class _SpyReschedule extends SpacedRepetitionService {
  _SpyReschedule(super.db);

  int rescheduleCalls = 0;

  @override
  Future<void> rescheduleReviewNotification() async {
    rescheduleCalls++;
  }
}
