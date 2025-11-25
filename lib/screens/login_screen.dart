import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import '../providers/auth_provider.dart';

/// 未認証ユーザー向けログイン画面
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              _Logo(),
              const SizedBox(height: 24),

              // Title and Subtitle
              _TitleSection(),
              const SizedBox(height: 48),

              // Sign in button
              const _SignInSection(),
              const SizedBox(height: 24),

              // Terms and Privacy
              _TermsText(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/splash_icon.png', width: 150, height: 150);
  }
}

class _TitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('SiteCat', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          'Website Monitoring Made Easy',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SignInSection extends StatelessWidget {
  const _SignInSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Column(
          children: [
            // Google Sign-In Button
            ElevatedButton.icon(
              onPressed: authProvider.isLoading
                  ? null
                  : () => authProvider.signInWithGoogle(),
              icon: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                authProvider.isLoading
                    ? 'Signing in...'
                    : 'Sign in with Google',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            // Apple Sign-In Button (iOS/macOS only)
            if (Platform.isIOS || Platform.isMacOS) ...[
              const SizedBox(height: 16),
              SignInWithAppleButton(
                onPressed: authProvider.isLoading
                    ? () {}
                    : () => authProvider.signInWithApple(),
                style: SignInWithAppleButtonStyle.black,
                height: 50,
              ),
            ],

            // Error message display
            if (authProvider.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorMessage(
                message: authProvider.errorMessage!,
                onClose: () => authProvider.clearError(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorMessage({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade700)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            color: Colors.red.shade700,
          ),
        ],
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'By signing in, you agree to our Terms of Service and Privacy Policy',
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
