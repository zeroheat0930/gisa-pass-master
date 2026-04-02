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

// 서비스는 앱 시작 시 한 번만 생성
late final DatabaseService _db;
late final PredictionEngine _predictionEngine;
late final SpacedRepetitionService _spacedRepetitionService;
late final AdService _adService;
late final PurchaseService _purchaseService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await AdService.initialize();

  _db = DatabaseService();
  _predictionEngine = PredictionEngine();
  _spacedRepetitionService = SpacedRepetitionService(_db);
  _adService = AdService()..loadInterstitialAd();
  _purchaseService = PurchaseService()
    ..setAdService(_adService)
    ..initialize();

  runApp(const GisaPassMasterApp());
}

class GisaPassMasterApp extends StatelessWidget {
  const GisaPassMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StudyProvider(
            db: _db,
            predictionEngine: _predictionEngine,
            spacedRepetitionService: _spacedRepetitionService,
            adService: _adService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StatsProvider(db: _db),
        ),
        ChangeNotifierProvider(
          create: (_) => _purchaseService,
        ),
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
        ),
        home: const _RootNavigator(),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = {0}; // 홈은 즉시 로드

  Widget _buildTab(int index) {
    switch (index) {
      case 0: return const HomeScreen();
      case 1: return PastExamScreen(loadQuestions: () => _db.getAllQuestions());
      case 2: return const CheatSheetScreen();
      case 3: return const StatsScreen();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(4, (i) =>
          _loadedTabs.contains(i) ? _buildTab(i) : const SizedBox.shrink(),
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
