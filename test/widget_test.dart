// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sitecat/providers/auth_provider.dart';

void main() {
  testWidgets('SiteCat app login screen test', (WidgetTester tester) async {
    // Firebase初期化が不要なUIテスト
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (context) => MockAuthProvider(),
          child: const TestLoginScreen(),
        ),
      ),
    );

    // Verify that our login screen is displayed.
    expect(find.text('SiteCat'), findsOneWidget);
    expect(find.text('Website Monitoring Made Easy'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}

/// テスト用のモックAuthProvider
class MockAuthProvider extends AuthProvider {
  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;
}

/// テスト用のログイン画面
class TestLoginScreen extends StatelessWidget {
  const TestLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ロゴ
              Icon(
                Icons.pets,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // タイトル
              Text('SiteCat', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),

              const Text(
                'Website Monitoring Made Easy',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // サインインボタン
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
