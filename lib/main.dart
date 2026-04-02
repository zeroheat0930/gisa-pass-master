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
import 'screens/home_screen.dart';
import 'screens/past_exam_screen.dart';
import 'screens/cheat_sheet_screen.dart';
import 'screens/stats_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // 광고 초기화 (실패해도 앱 실행 가능)
  try {
    await AdService.initialize();
  } catch (e) {
    debugPrint('Ad init failed: $e');
  }

  // 서비스 생성 (앱 수명 동안 한 번만)
  final db = DatabaseService();
  final predictionEngine = PredictionEngine();
  final spacedRepetitionService = SpacedRepetitionService(db);
  final adService = AdService()..loadInterstitialAd();
  final purchaseService = PurchaseService()..setAdService(adService);

  // 구매 서비스 초기화 (await — 레이스 컨디션 방지)
  try {
    await purchaseService.initialize();
  } catch (e) {
    debugPrint('Purchase init failed: $e');
  }

  // DB 워밍업 — 첫 쿼리 전에 DB 준비 (흰 화면 방지)
  try {
    await db.database;
  } catch (e) {
    debugPrint('DB init failed: $e');
  }

  runApp(GisaPassMasterApp(
    db: db,
    predictionEngine: predictionEngine,
    spacedRepetitionService: spacedRepetitionService,
    adService: adService,
    purchaseService: purchaseService,
  ));
}

class GisaPassMasterApp extends StatelessWidget {
  final DatabaseService db;
  final PredictionEngine predictionEngine;
  final SpacedRepetitionService spacedRepetitionService;
  final AdService adService;
  final PurchaseService purchaseService;

  const GisaPassMasterApp({
    super.key,
    required this.db,
    required this.predictionEngine,
    required this.spacedRepetitionService,
    required this.adService,
    required this.purchaseService,
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
        home: _RootNavigator(db: db),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  final DatabaseService db;
  const _RootNavigator({required this.db});

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0};

  // 탭별 위젯 캐싱 — 매 빌드마다 재생성 방지
  final Map<int, Widget> _cachedTabs = {};

  Widget _getTab(int index) {
    return _cachedTabs.putIfAbsent(index, () {
      switch (index) {
        case 0: return const HomeScreen();
        case 1: return PastExamScreen(loadQuestions: () => widget.db.getAllQuestions());
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
            icon: const Icon(Icons.history_edu_outlined),
            selectedIcon: Icon(Icons.history_edu, color: AppConfig.primaryColor),
            label: '기출문제',
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
