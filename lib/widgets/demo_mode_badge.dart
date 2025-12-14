import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/dialogs.dart';

/// Demo mode badge widget displayed at the top of the screen
class DemoModeBadge extends StatelessWidget {
  const DemoModeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isDemoMode) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange.shade700,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Demo Mode',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  _showExitDemoDialog(context, authProvider);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExitDemoDialog(BuildContext context, AuthProvider authProvider) {
    Dialogs.confirm(
      context,
      title: 'Exit Demo Mode',
      message:
          'Are you sure you want to exit demo mode? You will be returned to the login screen.',
      okText: 'Exit',
      cancelText: 'Cancel',
    ).then((confirmed) {
      if (confirmed) {
        authProvider.exitDemoMode();
      }
    });
  }
}
