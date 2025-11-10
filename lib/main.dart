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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SiteProvider>().initialize();
      }
    });

    _screens = [
      DashboardScreen(
        onNavigateToSites: () {
          setState(() {
            _currentIndex = 1; // Switch to Sites tab
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
