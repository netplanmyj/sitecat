import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// プロフィール画面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Card
                _ProfileCard(user: user),
                const SizedBox(height: 24),

                // Sign Out Button
                _SignOutButton(authProvider: authProvider),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final dynamic user;

  const _ProfileCard({required this.user});

  /// ユーザー表示名を取得
  /// displayName があればそれを使用、なければメールアドレスの@より前を使用
  String _getDisplayName(dynamic user) {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    // displayName がない場合、メールアドレスから生成
    if (user?.email != null) {
      final email = user!.email as String;
      final username = email.split('@').first;
      return username;
    }

    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _getDisplayName(user),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final AuthProvider authProvider;

  const _SignOutButton({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSignOutDialog(context),
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              authProvider.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
