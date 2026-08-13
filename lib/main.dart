import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'config.dart';
import 'providers/study_provider.dart';
import 'providers/stats_provider.dart';
import 'services/database_service.dart';
import 'services/prediction_engine.dart';
import 'services/spaced_repetition_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'services/license_notices.dart';
import 'services/notification_service.dart';
import 'widgets/notification_opt_in.dart';
import 'services/study_plan_service.dart';
import 'screens/home_screen.dart';
import 'screens/past_exam_screen.dart';
import 'screens/cheat_sheet_screen.dart';
import 'screens/stats_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // 문항 데이터의 출처·라이선스를 Flutter 라이선스 목록에 등록한다.
  // 패키지가 아닌 저작물은 Flutter 가 자동으로 모아주지 않는다.
  LicenseNotices.register();

  // 서비스 생성 (앱 수명 동안 한 번만)
  final db = DatabaseService();
  final predictionEngine = PredictionEngine();
  final spacedRepetitionService = SpacedRepetitionService(db);
  final adService = AdService();
  setGlobalAdService(adService);
  final purchaseService = PurchaseService()..setAdService(adService);
  final studyPlanService = StudyPlanService(db);

  // 첫 프레임 전에 기다리는 건 이 둘뿐이다. 나머지 초기화(AdMob SDK·스토어
  // 연결·알림)는 첫 프레임 이후에 한다 (_RootNavigator.initState 참조).
  // 예전에는 AdMob SDK(수 초 가능)와 스토어 왕복 2회(상품 조회 + 자동 복원)까지
  // 타임아웃 없이 직렬로 await 해서, 콜드 스타트가 세 지연의 합이었고 최초 설치
  // 첫 실행에선 스플래시 위로 Apple ID 로그인 시트가 뜰 수 있었다.
  try {
    await Future.wait([
      // 프리미엄 캐시 복원(로컬) — 안 하면 결제 유저에게 첫 화면 광고가 샌다
      purchaseService.restoreCachedPremium(),
      // DB 워밍업 — 첫 쿼리 전에 DB 준비 (흰 화면 방지)
      db.database,
    ]);
  } catch (e) {
    debugPrint('Startup init failed: $e');
  }

  runApp(GisaPassMasterApp(
    db: db,
    predictionEngine: predictionEngine,
    spacedRepetitionService: spacedRepetitionService,
    adService: adService,
    purchaseService: purchaseService,
    studyPlanService: studyPlanService,
  ));
}

class GisaPassMasterApp extends StatelessWidget {
  final DatabaseService db;
  final PredictionEngine predictionEngine;
  final SpacedRepetitionService spacedRepetitionService;
  final AdService adService;
  final PurchaseService purchaseService;
  final StudyPlanService studyPlanService;

  const GisaPassMasterApp({
    super.key,
    required this.db,
    required this.predictionEngine,
    required this.spacedRepetitionService,
    required this.adService,
    required this.purchaseService,
    required this.studyPlanService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StudyProvider(
            db: db,
            predictionEngine: predictionEngine,
            spacedRepetitionService: spacedRepetitionService,
            adService: adService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StatsProvider(db: db),
        ),
        ChangeNotifierProvider.value(value: purchaseService),
        ChangeNotifierProvider.value(value: studyPlanService),
      ],
      child: MaterialApp(
        title: AppConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConfig.primaryColor,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: AppConfig.backgroundColor,
          appBarTheme: AppBarTheme(
            backgroundColor: AppConfig.backgroundColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppConfig.cardColor,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: _RootNavigator(
          db: db,
          spacedRepetitionService: spacedRepetitionService,
        ),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  final DatabaseService db;
  final SpacedRepetitionService spacedRepetitionService;
  const _RootNavigator({required this.db, required this.spacedRepetitionService});

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();

    // 알림을 켜는 모든 경로(옵트인 다이얼로그 / 통계 화면 토글)의 후속 작업은
    // **동기적으로, 첫 프레임 전에** 물려둔다. postFrame 체인(광고 SDK·ATT·
    // 스토어 왕복) 끝에서 할당하면 그 수 초 동안 통계 탭에서 토글을 켠 유저의
    // 복습 알림이 예약되지 않고, 체인이 중간에 죽으면 세션 내내 그렇다.
    NotificationOptIn.onEnabled =
        widget.spacedRepetitionService.rescheduleReviewNotification;

    // iOS ATT 권한 요청 — IDFA 접근 동의 (광고 fill rate 에 직결).
    //
    // runApp() 이전에 요청하면 앱이 아직 active 상태가 아니라 프롬프트가 그대로
    // 무시될 수 있다(스플래시가 멈춘 것처럼 보이기도 한다). 첫 프레임이 그려진 뒤
    // 요청해야 확실히 뜬다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // AdMob SDK 초기화 — 수 초 걸릴 수 있어 runApp 전에 둘 이유가 없다.
      try {
        await AdService.initialize();
      } catch (e) {
        debugPrint('Ad init failed: $e');
      }

      // 순서가 중요하다: ATT 동의를 먼저 받고 그 다음에 첫 광고를 요청한다.
      // 반대로 하면 IDFA 없이 광고를 요청하게 되어 ATT 를 띄우는 의미가 없다.
      await _requestTracking();
      globalAdService?.loadInterstitialAd();
      globalAdService?.loadRewardedAd();

      // 스토어 연결(상품 조회 + 설치당 1회 자동 복원). ATT 뒤에 두는 이유:
      // 최초 설치에서 자동 복원이 띄울 수 있는 Apple ID 로그인 시트가
      // ATT 다이얼로그와 겹치지 않게 한다. 프리미엄 캐시는 이미 첫 프레임
      // 전에 복원됐으므로 여기가 늦어도 결제 유저에게 광고가 새지 않는다.
      if (mounted) {
        try {
          await context.read<PurchaseService>().initialize();
        } catch (e) {
          debugPrint('Purchase init failed: $e');
        }
      }

      // 알림 초기화 + 예약 갱신. 유저가 켜둔 경우에만 실제로 예약된다.
      await NotificationService.initialize();

      await NotificationService.scheduleExamCountdown();
      await widget.spacedRepetitionService.rescheduleReviewNotification();
    });
  }

  /// 통합 테스트에서는 ATT 시스템 모달이 앱을 덮어 자동화가 진행되지 않는다.
  /// 시뮬레이터는 이 권한을 미리 설정할 수도 없어서(simctl privacy 불가),
  /// 테스트 실행 시에만 건너뛴다. 실제 빌드에는 영향이 없다.
  static const bool _skipTracking =
      bool.fromEnvironment('SKIP_ATT', defaultValue: false);

  Future<void> _requestTracking() async {
    if (_skipTracking) return;
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      // 첫 프레임 직후 바로 띄우면 시스템이 삼키는 경우가 있어 한 박자 둔다.
      await Future.delayed(const Duration(milliseconds: 500));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('ATT 요청 실패: $e');
    }
  }

  // 탭별 위젯 캐싱 — 매 빌드마다 재생성 방지
  final Map<int, Widget> _cachedTabs = {};

  Widget _getTab(int index) {
    return _cachedTabs.putIfAbsent(index, () {
      switch (index) {
        case 0: return HomeScreen(db: widget.db);
        case 1: return PastExamScreen(db: widget.db);
        case 2: return const CheatSheetScreen();
        case 3: return const StatsScreen();
        default: return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(4, (i) =>
          _loadedTabs.contains(i) ? _getTab(i) : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          _loadedTabs.add(index);
          setState(() => _selectedIndex = index);

          // IndexedStack 은 탭을 계속 살려두므로 initState 가 다시 돌지 않는다.
          // 그래서 문제를 풀어도 홈·통계 화면이 앱 재시작 전까지 옛 값을 붙들고 있었다.
          // 통계를 보여주는 탭으로 이동할 때마다 다시 읽는다.
          if (index == 0 || index == 3) {
            context.read<StatsProvider>().loadStats();
          }
        },
        backgroundColor: AppConfig.surfaceColor,
        indicatorColor: AppConfig.primaryColor.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppConfig.primaryColor),
            label: '홈',
          ),
          NavigationDestination(
            icon: const Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz, color: AppConfig.primaryColor),
            label: '문제은행',
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: AppConfig.primaryColor),
            label: '족보',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppConfig.primaryColor),
            label: '통계',
          ),
        ],
      ),
    );
  }
}
