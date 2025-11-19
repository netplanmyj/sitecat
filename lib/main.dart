import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/site_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/link_checker_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sites_screen.dart';
import 'screens/results_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const SiteCatApp());
  } catch (e) {
    runApp(_FirebaseErrorApp(error: e.toString()));
  }
}

/// Firebase初期化エラー画面
class _FirebaseErrorApp extends StatelessWidget {
  const _FirebaseErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $error',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SiteCatApp extends StatelessWidget {
  const SiteCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _buildProviders(),
      child: MaterialApp(
        title: 'SiteCat',
        theme: _buildTheme(),
        home: const _AuthRouter(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// アプリ全体で使用するプロバイダーを構築
  List<ChangeNotifierProvider> _buildProviders() {
    return [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => SiteProvider()),
      ChangeNotifierProvider(create: (_) => MonitoringProvider()),
      ChangeNotifierProvider(create: (_) => LinkCheckerProvider()),
    ];
  }

  /// アプリのテーマを構築
  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      textTheme: _buildTextTheme(),
    );
  }

  /// カスタムテキストテーマを構築（フォントサイズを1段階大きく）
  TextTheme _buildTextTheme() {
    return ThemeData.light().textTheme.copyWith(
      bodyLarge: const TextStyle(fontSize: 18), // 16 → 18
      bodyMedium: const TextStyle(fontSize: 16), // 14 → 16
      bodySmall: const TextStyle(fontSize: 14), // 12 → 14
      labelLarge: const TextStyle(fontSize: 16), // 14 → 16 (ボタン)
      labelMedium: const TextStyle(fontSize: 14), // 12 → 14
      labelSmall: const TextStyle(fontSize: 12), // 11 → 12
    );
  }
}

/// 認証状態に応じた画面ルーティング
class _AuthRouter extends StatelessWidget {
  const _AuthRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return authProvider.isAuthenticated
            ? const AuthenticatedHome()
            : const LoginScreen();
      },
    );
  }
}

/// 認証済みユーザー向けホーム画面
class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  int _currentIndex = 0;
  bool _monitoringInitialized = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
    _initializeProviders();
  }

  /// タブ画面のリストを構築
  List<Widget> _buildScreens() {
    return [
      DashboardScreen(
        onNavigateToSites: () => _navigateToTab(1),
        onNavigateToResults: () => _navigateToTab(2),
      ),
      const SitesScreen(),
      const ResultsScreen(),
      const ProfileScreen(),
    ];
  }

  /// 指定したタブに遷移
  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// プロバイダーの初期化
  void _initializeProviders() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SiteProvider>().initialize();
      }
    });
  }

  /// サイトが登録されたら監視を開始
  void _initializeMonitoringIfNeeded(SiteProvider siteProvider) {
    if (siteProvider.sites.isNotEmpty && !_monitoringInitialized) {
      _monitoringInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MonitoringProvider>().initializeFromSites(siteProvider);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteProvider = context.watch<SiteProvider>();
    _initializeMonitoringIfNeeded(siteProvider);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// ボトムナビゲーションバーを構築
  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _navigateToTab,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.web), label: 'Sites'),
        BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Results'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
