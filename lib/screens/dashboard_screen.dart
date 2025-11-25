import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/link_checker_provider.dart';
import '../widgets/dashboard/welcome_card.dart';
import '../widgets/dashboard/my_sites_section.dart';
import '../widgets/dashboard/recent_activity_section.dart';
import '../widgets/demo_mode_badge.dart';

/// ダッシュボード画面
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSites;
  final VoidCallback? onNavigateToResults;

  const DashboardScreen({
    super.key,
    this.onNavigateToSites,
    this.onNavigateToResults,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load recent activity data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkCheckerProvider>().loadAllCheckHistory(limit: 5);
    });
  }

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

          return Column(
            children: [
              // Demo Mode Badge
              const DemoModeBadge(),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      WelcomeCard(user: user),
                      const SizedBox(height: 24),

                      // My Sites Section
                      MySitesSection(
                        onNavigateToSites: widget.onNavigateToSites,
                      ),
                      const SizedBox(height: 24),

                      // Recent Activity Section
                      RecentActivitySection(
                        onNavigateToResults: widget.onNavigateToResults,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
