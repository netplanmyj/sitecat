import 'package:flutter/material.dart';

/// Welcome card widget showing user profile information
class WelcomeCard extends StatelessWidget {
  final dynamic user;

  const WelcomeCard({super.key, required this.user});

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
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _getDisplayName(user),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
