import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/study_provider.dart';
import '../screens/ai_prediction_screen.dart';
import '../screens/subscription_screen.dart';
import '../widgets/exam_quota_dialog.dart';
import 'ai_exam_quota.dart';
import 'purchase_service.dart';

/// AI 실전 모의고사 진입의 **단일 정본**.
///
/// 게이트 확인 → 쿼터 소진 안내 → 문제 로드 → 화면 push 까지 한 벌만 존재한다.
/// 홈과 복원 기출 결과 화면이 각자 이 흐름을 갖고 있으면, 이 저장소에서 반복된
/// 사고(같은 것을 복붙하고 한쪽만 고치는 것)가 **수익 게이트에서** 재발한다 —
/// 한쪽 입구만 쿼터를 안 물어보면 무료 하루 1회 제한이 통째로 무의미해진다.
///
/// **이중 탭 가드는 호출부가 가진다.** 화면마다 상태(`_isNavigating`)가 따로라
/// 여기서 들 수 없다. 호출부는 반드시 `await` **앞**에서 플래그를 세우고
/// `finally` 에서 내릴 것 — 쿼터 조회를 기다리는 사이 두 번째 탭이 통과하면
/// 모의고사 화면이 두 번 쌓이고 무료 응시도 2회 소모된다.
Future<void> startAiExam(BuildContext context) async {
  // 구독 화면은 AI 모의고사를 유료 전용으로 광고하는데 게이트가 없었다.
  // 완전히 막으면 쓰던 유저에게서 기능을 빼앗는 것이라 하루 1회는 열어둔다.
  final isPremium = context.read<PurchaseService>().isPremium;
  if (!await AiExamQuota.canStart(isPremium: isPremium)) {
    if (!context.mounted) return;
    final earned = await ExamQuotaDialog.show(
      context,
      isPremium: isPremium,
      onSeePremium: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const SubscriptionScreen()),
      ),
    );
    // 광고를 끝까지 봐서 1회를 얻었으면 그대로 이어서 응시한다.
    if (!earned || !context.mounted) return;
  }

  HapticFeedback.lightImpact();
  final provider = context.read<StudyProvider>();
  await provider.loadQuestions();
  // 쿼터는 여기서 깎지 않는다. 로딩 중에 뒤로가기로 빠져나가면 시험을 보지도
  // 않고 무료 1회가 증발한다. 소모는 시험이 실제로 시작되는 시점
  // (AiPredictionScreen 의 로딩 완료)에서 한다.
  if (!context.mounted) return;

  final questions = provider.questionList;
  if (questions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('문제가 없습니다.')),
    );
    return;
  }

  final examQuestions = questions.take(20).toList();
  await Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (_) => AiPredictionScreen(questions: examQuestions),
    ),
  );
}
