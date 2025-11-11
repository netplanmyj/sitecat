import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard/welcome_card.dart';
import '../widgets/dashboard/my_sites_section.dart';
import '../widgets/dashboard/recent_activity_section.dart';

/// ダッシュボード画面
class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSites;
  final VoidCallback? onNavigateToResults;

  const DashboardScreen({
    super.key,
    this.onNavigateToSites,
    this.onNavigateToResults,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                WelcomeCard(user: user),
                const SizedBox(height: 24),

                // My Sites Section
                MySitesSection(onNavigateToSites: onNavigateToSites),
                const SizedBox(height: 24),

                // Recent Activity Section
                RecentActivitySection(onNavigateToResults: onNavigateToResults),
              ],
            ),
          );
        },
      ),
    );
  }
}
