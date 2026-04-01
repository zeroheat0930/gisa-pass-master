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
import 'screens/stats_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await AdService.initialize();
  runApp(const GisaPassMasterApp());
}

class GisaPassMasterApp extends StatelessWidget {
  const GisaPassMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final predictionEngine = PredictionEngine();
    final spacedRepetitionService = SpacedRepetitionService(db);
    final adService = AdService()..loadInterstitialAd();
    final purchaseService = PurchaseService()..initialize();

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

  List<Widget> _screens(BuildContext context) => [
    const HomeScreen(),
    PastExamScreen(
      loadQuestions: () => Provider.of<StudyProvider>(context, listen: false).db.getAllQuestions(),
    ),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens(context),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
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
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppConfig.primaryColor),
            label: '통계',
          ),
        ],
      ),
    );
  }
}
