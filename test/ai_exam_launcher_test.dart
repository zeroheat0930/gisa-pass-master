import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/models/question.dart';
import 'package:gisa_pass_master/providers/study_provider.dart';
import 'package:gisa_pass_master/screens/subscription_screen.dart';
import 'package:gisa_pass_master/services/ai_exam_launcher.dart';
import 'package:gisa_pass_master/services/ai_exam_quota.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/prediction_engine.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/services/spaced_repetition_service.dart';

// 쿼터 소진 다이얼로그 → 프리미엄 → 결제 후 복귀 경로.
//
// 예전에는 onSeePremium 을 기다리지 않아, 구독 화면에서 프리미엄이 되어 돌아와도
// 모의고사가 이어지지 않았다. 방금 돈을 낸 유저가 버튼을 다시 찾아 눌러야 했다.

/// 구독 화면 안에서 결제가 끝난 것처럼 프리미엄을 켤 수 있는 가짜.
class _FlippablePurchaseService extends PurchaseService {
  bool premium = false;

  @override
  bool get isPremium => premium;
}

/// 문제가 비어 있는 StudyProvider. 게이트를 통과하면 '문제가 없습니다.' 안내가
/// 뜨므로, 그 안내가 곧 '응시 단계로 진입했다'는 신호다.
class _EmptyStudyProvider extends StudyProvider {
  _EmptyStudyProvider._(DatabaseService db)
      : super(
          db: db,
          predictionEngine: PredictionEngine(),
          spacedRepetitionService: SpacedRepetitionService(db),
        );

  factory _EmptyStudyProvider() => _EmptyStudyProvider._(DatabaseService());

  @override
  Future<void> loadQuestions() async {}

  @override
  List<Question> get questionList => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FlippablePurchaseService purchase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    purchase = _FlippablePurchaseService();
  });

  Widget host() => MultiProvider(
        providers: [
          ChangeNotifierProvider<PurchaseService>.value(value: purchase),
          ChangeNotifierProvider<StudyProvider>.value(
              value: _EmptyStudyProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => startAiExam(context),
                child: const Text('모의고사'),
              ),
            ),
          ),
        ),
      );

  Future<void> goToSubscription(WidgetTester tester) async {
    await AiExamQuota.consume(isPremium: false); // 오늘 무료 1회 소진
    await tester.pumpWidget(host());
    await tester.tap(find.text('모의고사'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 무료 모의고사 완료'), findsOneWidget);
    await tester.tap(find.text('프리미엄'));
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget, reason: '테스트 전제 확인');
  }

  void popSubscription(WidgetTester tester) {
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
  }

  testWidgets('구독 화면에서 프리미엄이 되어 돌아오면 바로 응시로 이어진다', (tester) async {
    await goToSubscription(tester);

    purchase.premium = true; // 결제 완료
    popSubscription(tester);
    await tester.pumpAndSettle();

    expect(find.text('문제가 없습니다.'), findsOneWidget,
        reason: '결제하고 돌아왔는데 모의고사가 시작되지 않으면 산 보람이 깎인다');
  });

  testWidgets('구매 없이 돌아오면 응시로 넘어가지 않는다', (tester) async {
    await goToSubscription(tester);

    popSubscription(tester);
    await tester.pumpAndSettle();

    expect(find.text('문제가 없습니다.'), findsNothing,
        reason: '구매 안 했는데 진입하면 무료 하루 1회 게이트가 뚫린다');
  });
}
