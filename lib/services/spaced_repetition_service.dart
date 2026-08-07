import 'package:flutter/foundation.dart';

import '../models/question.dart';
import 'notification_service.dart';
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
  ///
  /// **정답일 때도 반드시 호출해야 한다.** v1.5.4 이전에는 호출부가 오답일 때만
  /// 이 함수를 불러서 stage 승격이 아예 일어나지 않았고, 그 결과
  /// (1) 한 번 오답노트에 들어간 문제가 영원히 졸업하지 못해 큐가 줄지 않았고
  /// (2) stage 가 0 에 고정되어 복습 간격이 항상 1분이었다.
  /// 큐 진입 조건(오답만 등록)은 호출부가 아니라 아래 가드가 책임진다.
  Future<void> processAnswer(int questionId, bool isCorrect) async {
    final existing = await _db.getSpacedRepetition(questionId);

    // 아직 복습 대상이 아닌 문제를 정답 처리한 경우엔 큐에 넣지 않는다.
    // 오답노트는 '틀린 적 있는 문제'만 담는다.
    if (isCorrect && existing == null) return;

    int currentStage = existing?['stage'] as int? ?? 0;
    int consecutiveCorrect = existing?['consecutive_correct'] as int? ?? 0;

    if (isCorrect) {
      currentStage = (currentStage + 1).clamp(0, _maxStage);
      consecutiveCorrect += 1;
    } else {
      // 틀렸으면 처음으로 되돌린다.
      // 2단계만 강등하면 stage 7(14일)에서 틀린 문제가 stage 5(3일) 로만 내려가,
      // 방금 틀린 문제를 사흘 뒤에나 다시 보게 된다. 망각곡선의 취지는
      // "틀린 건 곧바로 다시"이므로 stage 0(1분)으로 리셋한다.
      currentStage = 0;
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

    // 스케줄이 바뀌었으니 복습 알림을 다시 잡는다.
    // 이 연결이 없으면 망각곡선 엔진이 계산만 하고 유저에게 도달하지 못한다.
    await rescheduleReviewNotification();
  }

  /// 현재 복습 큐를 기준으로 알림을 다시 예약한다.
  Future<void> rescheduleReviewNotification() async {
    try {
      final next = await _db.getNextReviewSchedule();
      if (next == null) return;
      await NotificationService.scheduleReviewReminder(
        dueAt: next.dueAt,
        dueCount: next.count,
      );
    } catch (e) {
      debugPrint('복습 알림 재예약 실패: $e');
    }
  }

  /// 현재 복습 기한이 된 문제 목록 반환
  Future<List<Question>> getDueQuestions() async {
    final rows = await _db.getDueReviews();
    return rows.map((row) => Question.fromMap(row)).toList();
  }
}
