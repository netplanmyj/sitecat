import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/site_provider.dart';
import 'providers/monitoring_provider.dart';
import 'providers/link_checker_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/subscription_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/sites_screen.dart';
import 'screens/results_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

// Global SubscriptionService instance
late final SubscriptionService subscriptionService;

void main() async {
  // Flutter binding の初期化
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase の初期化（必ず runApp より前に完了させる）
  // Note: Uses native configuration files (google-services.json/GoogleService-Info.plist)
  // which are set to production environment (sitecat-prod)
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (e) {
    // If duplicate-app error occurs, it means Firebase is already initialized at native layer
    // This is expected behavior in some environments (e.g., TestFlight)
    if (e.code != 'duplicate-app') {
      // For other errors, rethrow
      rethrow;
    }
    // Firebase already initialized at native layer
  }

  // Initialize SubscriptionService
  subscriptionService = SubscriptionService();
  await subscriptionService.initialize();

  runApp(const SiteCatApp());
}

class SiteCatApp extends StatelessWidget {
  const SiteCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => SiteProvider()),
        ChangeNotifierProvider(create: (context) => MonitoringProvider()),
        ChangeNotifierProvider(create: (context) => LinkCheckerProvider()),
        ChangeNotifierProvider(
          create: (context) => SubscriptionProvider(subscriptionService),
        ),
      ],
      child: MaterialApp(
        title: 'SiteCat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // フォントサイズを1段階大きく（デフォルト14px → 16px）
          textTheme: ThemeData.light().textTheme.copyWith(
            bodyLarge: const TextStyle(fontSize: 18), // 16 → 18
            bodyMedium: const TextStyle(fontSize: 16), // 14 → 16
            bodySmall: const TextStyle(fontSize: 14), // 12 → 14
            labelLarge: const TextStyle(fontSize: 16), // 14 → 16 (ボタン)
            labelMedium: const TextStyle(fontSize: 14), // 12 → 14
            labelSmall: const TextStyle(fontSize: 12), // 11 → 12
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // 認証状態に基づいて画面を切り替え
            if (authProvider.isAuthenticated) {
              return const AuthenticatedHome();
            } else {
              return const LoginScreen();
            }
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
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

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final isDemoMode = authProvider.isDemoMode;
      final siteProvider = context.read<SiteProvider>();
      final linkCheckerProvider = context.read<LinkCheckerProvider>();
      final monitoringProvider = context.read<MonitoringProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      // Initialize providers with demo mode flag
      await siteProvider.initialize(isDemoMode: isDemoMode);
      if (!mounted) return;

      // Initialize subscription provider and sync premium status to all providers
      // TODO: Security - Fetch limits from backend instead of client-side calculation
      // Currently, premium status and limits are determined client-side which can be
      // bypassed by tampering. Future implementation should:
      // 1. Verify entitlements server-side on each request
      // 2. Fetch allowed limits (maxSites, maxPages, maxHistory) from backend
      // 3. Have backend as the source of truth for all premium features
      await subscriptionProvider.initialize();
      if (!mounted) return;

      final isPremium = subscriptionProvider.hasLifetimeAccess;
      siteProvider.setHasLifetimeAccess(isPremium);
      linkCheckerProvider.setHasLifetimeAccess(isPremium);
      monitoringProvider.setHasLifetimeAccess(isPremium);

      linkCheckerProvider.initialize(isDemoMode: isDemoMode);
    });

    _screens = [
      DashboardScreen(
        onNavigateToSites: () {
          setState(() {
            _currentIndex = 1; // Switch to Sites tab
          });
        },
        onNavigateToResults: () {
          setState(() {
            _currentIndex = 2; // Switch to Results tab
          });
        },
      ),
      const SitesScreen(),
      const ResultsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Initialize monitoring when sites are available
    final siteProvider = context.watch<SiteProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDemoMode = authProvider.isDemoMode;

    if (siteProvider.sites.isNotEmpty &&
        !_monitoringInitialized &&
        !isDemoMode) {
      _monitoringInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MonitoringProvider>().initializeFromSites(siteProvider);
        }
      });
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.web), label: 'Sites'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Results',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
