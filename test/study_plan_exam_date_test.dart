import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gisa_pass_master/config.dart';
import 'package:gisa_pass_master/models/study_plan.dart';
import 'package:gisa_pass_master/screens/study_plan_screen.dart';
import 'package:gisa_pass_master/services/database_service.dart';
import 'package:gisa_pass_master/services/plan_reset_quota.dart';
import 'package:gisa_pass_master/services/purchase_service.dart';
import 'package:gisa_pass_master/services/study_plan_service.dart';

/// 학습 플랜은 시작일 기준 달력으로만 흘러간다. 예전에는 미션 문구에
/// 'D-2!'·'시험 당일!' 을 박아둬서, 10/15(D-10) 에 14일 플랜을 시작하면
/// 시험(10/25) 뒤인 10/27~29 에 'D-2!'·'시험 당일!' 이 떴다 — 그것도 돈 낸
/// 구간(Day 4+)에서. 문구는 이제 **실제 날짜**로 정한다.
///
/// 2026-3회 시험일은 10/25(확정)이다.
void main() {
  tearDown(() => AppConfig.nowForTest = null);

  ({String title, String description}) textOf(
    String planType,
    int day,
    DateTime start,
  ) {
    final mission = StudyPlanService.getMissionsForPlanType(
      planType,
    ).firstWhere((m) => m.dayNumber == day);
    return StudyPlanService.missionTextFor(mission, start);
  }

  group('미션 문구는 실제 날짜로 판정한다', () {
    test('10/15 시작 14일 플랜: Day11 이 시험 당일, Day12 이후는 중립 문구', () {
      AppConfig.nowForTest = () => DateTime(2026, 10, 15, 9);
      final start = DateTime(2026, 10, 15, 9, 30);

      expect(
        textOf('14day', 11, start).title,
        startsWith('시험 당일!'),
        reason: '10/15 + 10일 = 10/25 시험일',
      );

      for (var day = 12; day <= 14; day++) {
        final t = textOf('14day', day, start);
        expect(
          t.description,
          startsWith('복습 · 다음 시험 대비'),
          reason: 'Day$day 는 시험 뒤다',
        );
        expect(
          '${t.title} ${t.description}',
          isNot(contains('시험 당일')),
          reason: 'Day$day 에 시험 당일 문구가 뜨면 안 된다',
        );
        expect(
          '${t.title} ${t.description}',
          isNot(contains('D-')),
          reason: 'Day$day 에 D-문구가 뜨면 안 된다',
        );
      }

      // 시험 전 날들에는 날짜 문구가 붙지 않는다(14일 플랜의 D-문구는 Day12 자리뿐).
      for (var day = 1; day <= 10; day++) {
        final t = textOf('14day', day, start);
        expect('${t.title} ${t.description}', isNot(contains('시험 당일')));
        expect(t.description, isNot(startsWith('복습 · 다음 시험 대비')));
      }
    });

    test('10/12 시작 14일 플랜: Day14 가 시험 당일, Day12 는 실제 D-2', () {
      AppConfig.nowForTest = () => DateTime(2026, 10, 12);
      final start = DateTime(2026, 10, 12, 21);

      expect(textOf('14day', 14, start).title, '시험 당일! 가볍게 복습');
      expect(textOf('14day', 12, start).description, startsWith('D-2!'));
      for (var day = 1; day <= 13; day++) {
        expect(
          textOf('14day', day, start).title,
          isNot(contains('시험 당일')),
          reason: 'Day$day 는 시험 전이다',
        );
      }
    });

    test('7일 플랜의 D-문구도 날짜를 따른다', () {
      // 10/19 시작이면 Day6 = 10/24 = D-1, Day7 = 시험 당일.
      expect(
        textOf('7day', 6, DateTime(2026, 10, 19)).description,
        startsWith('D-1!'),
      );
      expect(
        textOf('7day', 7, DateTime(2026, 10, 19)).title,
        startsWith('시험 당일!'),
      );

      // 10/22 시작이면 Day4 = 시험일, Day6 은 시험 뒤라 D-문구가 없다.
      expect(
        textOf('7day', 4, DateTime(2026, 10, 22)).title,
        startsWith('시험 당일!'),
      );
      final day6 = textOf('7day', 6, DateTime(2026, 10, 22));
      expect(day6.description, startsWith('복습 · 다음 시험 대비'));
      expect(day6.description, isNot(contains('D-')));
    });

    test('플랜이 겨냥한 시험일이 추정치면 날짜 문구를 쓰지 않는다', () {
      // 확정 일정이 바닥난 먼 미래 — nextExam 은 추정 경로로 간다.
      final start = DateTime(2035, 10, 15);
      AppConfig.nowForTest = () => start;
      expect(AppConfig.isExamDateConfirmed, isFalse);

      for (final planType in ['1day', '3day', '5day', '7day', '14day']) {
        for (final m in StudyPlanService.getMissionsForPlanType(planType)) {
          final t = StudyPlanService.missionTextFor(m, start);
          expect(t.title, m.title, reason: '$planType Day${m.dayNumber}');
          expect(
            t.description,
            m.description,
            reason: '$planType Day${m.dayNumber}',
          );
        }
      }
    });

    test('미션 상수에는 날짜 가정 문구가 박혀 있지 않다', () {
      for (final planType in ['1day', '3day', '5day', '7day', '14day']) {
        for (final m in StudyPlanService.getMissionsForPlanType(planType)) {
          final text = '${m.title} ${m.description}';
          expect(
            text,
            isNot(matches(RegExp(r'D-\d'))),
            reason: '$planType Day${m.dayNumber}: $text',
          );
          expect(
            text,
            isNot(contains('시험 당일')),
            reason: '$planType Day${m.dayNumber}: $text',
          );
        }
      }
    });
  });

  group('플랜 선택 화면 — 시험일을 넘기는 플랜에만 경고', () {
    Finder cardOf(String title) => find
        .ancestor(of: find.text(title), matching: find.byType(GestureDetector))
        .first;

    Future<void> pumpSelection(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<StudyPlanService>.value(
          value: _NoPlanService(),
          child: const MaterialApp(home: StudyPlanScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('D-10: 14일 플랜에만 경고, 7일 완성이 추천', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 10, 15, 9);
      await pumpSelection(tester);

      final warning = find.text('시험(10월 25일)까지 10일 남아 이 플랜은 시험 뒤까지 이어져요');
      expect(warning, findsOneWidget);
      expect(
        find.descendant(of: cardOf('14일 합격 플랜'), matching: warning),
        findsOneWidget,
        reason: '경고는 14일 플랜 카드에 붙어야 한다',
      );

      expect(find.text('추천'), findsOneWidget);
      expect(
        find.descendant(of: cardOf('7일 완성'), matching: find.text('추천')),
        findsOneWidget,
        reason: '시험일 안에 끝나는 가장 긴 플랜은 7일',
      );

      // 경고만 — 카드는 여전히 다섯 개 다 보이고 고를 수 있다.
      expect(find.text('14일 합격 플랜'), findsOneWidget);
    });

    testWidgets('D-2: 5·7·14일 플랜에 경고, 3일이 추천', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 10, 23);
      await pumpSelection(tester);

      expect(find.textContaining('시험 뒤까지 이어져요'), findsNWidgets(3));
      for (final title in ['당일치기 전사', '48시간 전사']) {
        expect(
          find.descendant(
            of: cardOf(title),
            matching: find.textContaining('시험 뒤까지'),
          ),
          findsNothing,
        );
      }
      expect(
        find.descendant(of: cardOf('48시간 전사'), matching: find.text('추천')),
        findsOneWidget,
      );
    });

    testWidgets('D-13 이상: 경고 없음, 14일 플랜이 추천', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 10, 12);
      await pumpSelection(tester);

      expect(find.textContaining('시험 뒤까지 이어져요'), findsNothing);
      expect(
        find.descendant(of: cardOf('14일 합격 플랜'), matching: find.text('추천')),
        findsOneWidget,
      );
    });

    testWidgets('카운트다운 창(60일) 밖이면 경고도 추천도 없다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 7, 25); // 다음 시험 10/25 까지 92일
      await pumpSelection(tester);

      expect(find.textContaining('시험 뒤까지 이어져요'), findsNothing);
      expect(find.text('추천'), findsNothing);
    });
  });

  group('시험이 끝난 플랜 — 새 플랜 배너', () {
    StudyPlan planFrom(DateTime start, {String type = '14day'}) =>
        StudyPlan(id: 1, startedAt: start, currentDay: 1, planType: type);

    test('플랜 시작 ≤ 확정 시험일 < 오늘일 때만 참', () {
      final plan = planFrom(DateTime(2026, 10, 12));
      AppConfig.nowForTest = () => DateTime(2026, 10, 25, 20);
      expect(StudyPlanService.examPassedSincePlanStart(plan), isFalse,
          reason: '시험 당일은 아직 아니다');
      AppConfig.nowForTest = () => DateTime(2026, 10, 26);
      expect(StudyPlanService.examPassedSincePlanStart(plan), isTrue);
      expect(plan.todayDay, 14, reason: 'todayDay 는 마지막 Day 에 멈춰 있다 — 배너가 필요한 이유');

      // 시험 뒤에 시작한 플랜은 겨냥한 확정 시험이 없어 배너 대상이 아니다.
      final after = planFrom(DateTime(2026, 10, 26));
      AppConfig.nowForTest = () => DateTime(2026, 11, 3);
      expect(StudyPlanService.examPassedSincePlanStart(after), isFalse);
    });

    Future<_PlanService> pumpPlan(WidgetTester tester, StudyPlan plan) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final service = _PlanService(plan);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StudyPlanService>.value(value: service),
            ChangeNotifierProvider<PurchaseService>(
                create: (_) => PurchaseService()),
          ],
          child: const MaterialApp(home: StudyPlanScreen()),
        ),
      );
      await tester.pump();
      return service;
    }

    const bannerText = '시험이 끝났어요. 다음 시험을 위해 새 플랜을 시작할까요?';

    testWidgets('시험 전에는 배너가 없다', (tester) async {
      AppConfig.nowForTest = () => DateTime(2026, 10, 20);
      await pumpPlan(tester, planFrom(DateTime(2026, 10, 12)));
      expect(find.text(bannerText), findsNothing);
    });

    testWidgets('시험 뒤: 배너 → 새 플랜 시작은 무료 초기화 쿼터를 쓰지 않는다',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await PlanResetQuota.resetForTest();
      AppConfig.nowForTest = () => DateTime(2026, 10, 27);
      final service = await pumpPlan(tester, planFrom(DateTime(2026, 10, 12)));

      expect(find.text(bannerText), findsOneWidget);
      await tester.tap(find.text('새 플랜 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 플랜 고르기'));
      await tester.pumpAndSettle();

      expect(service.resetCalls, 1);
      expect(find.text(bannerText), findsNothing);
      expect(find.text('14일 합격 플랜'), findsOneWidget,
          reason: '리셋 뒤에는 플랜 선택 화면으로 돌아간다');
      expect(await PlanResetQuota.canReset(isPremium: false), isTrue,
          reason: '시험 뒤 새 플랜은 하루 1회 무료 초기화를 깎지 않는다');
    });
  });
}

/// 진행 중인 플랜 하나를 들고 있는 서비스(DB 접근 없음).
class _PlanService extends StudyPlanService {
  _PlanService(this._plan) : super(DatabaseService());

  StudyPlan? _plan;
  int resetCalls = 0;

  @override
  StudyPlan? get currentPlan => _plan;

  @override
  Future<void> loadCurrentPlan() async {}

  @override
  Future<void> resetPlan() async {
    resetCalls++;
    _plan = null;
    notifyListeners();
  }
}

/// 플랜이 없는 상태로 선택 화면만 띄운다(DB 접근 없음).
class _NoPlanService extends StudyPlanService {
  _NoPlanService() : super(DatabaseService());

  @override
  Future<void> loadCurrentPlan() async {}
}
