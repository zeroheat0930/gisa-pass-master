import '../models/question.dart';
import 'database_service.dart';

/// 에빙하우스 망각곡선 기반 스파르타 오답노트
/// 8단계 복습 인터벌: 1분, 10분, 1시간, 6시간, 1일, 3일, 7일, 14일
class SpacedRepetitionService {
  final DatabaseService _db;

  SpacedRepetitionService(this._db);

  // 8단계 인터벌 (분 단위)
  static const List<int> _intervalMinutes = [
    1,      // stage 0 → 1분 후
    10,     // stage 1 → 10분 후
    60,     // stage 2 → 1시간 후
    360,    // stage 3 → 6시간 후
    1440,   // stage 4 → 1일 후
    4320,   // stage 5 → 3일 후
    10080,  // stage 6 → 7일 후
    20160,  // stage 7 → 14일 후
  ];

  static const int _maxStage = 7;

  /// 답안 처리: DB의 spaced_repetition 테이블 갱신
  /// 정답 시: stage +1 (최대 7), consecutiveCorrect +1
  /// 오답 시: stage -2 (최소 0), consecutiveCorrect 초기화
  Future<void> processAnswer(int questionId, bool isCorrect) async {
    final existing = await _db.getSpacedRepetition(questionId);

    int currentStage = existing?['stage'] as int? ?? 0;
    int consecutiveCorrect = existing?['consecutive_correct'] as int? ?? 0;

    if (isCorrect) {
      currentStage = (currentStage + 1).clamp(0, _maxStage);
      consecutiveCorrect += 1;
    } else {
      currentStage = (currentStage - 2).clamp(0, _maxStage);
      consecutiveCorrect = 0;
    }

    final intervalMinutes = _intervalMinutes[currentStage];
    final nextReviewAt = DateTime.now().add(Duration(minutes: intervalMinutes));

    await _db.upsertSpacedRepetition(
      questionId: questionId,
      stage: currentStage,
      nextReviewAt: nextReviewAt,
      consecutiveCorrect: consecutiveCorrect,
    );
  }

  /// 현재 복습 기한이 된 문제 목록 반환
  Future<List<Question>> getDueQuestions() async {
    final rows = await _db.getDueReviews();
    return rows.map((row) => Question.fromMap(row)).toList();
  }
}
