import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/site_provider.dart';
import '../services/monitoring_service.dart';
import '../services/link_checker_service.dart';
import '../models/monitoring_result.dart';
import '../models/broken_link.dart';

/// ダッシュボード画面
class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSites;

  const DashboardScreen({super.key, this.onNavigateToSites});

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
                _WelcomeCard(user: user),
                const SizedBox(height: 24),

                // My Sites Section
                const _MySitesSection(),
                const SizedBox(height: 24),

                // Recent Activity placeholder
                Center(
                  child: Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: const _RecentActivityCard(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final dynamic user;

  const _WelcomeCard({required this.user});

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
                    user?.displayName ?? 'User',
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

class _MySitesSection extends StatelessWidget {
  const _MySitesSection();

  @override
  Widget build(BuildContext context) {
    // Find the parent DashboardScreen to get the callback
    final dashboardScreen = context
        .findAncestorWidgetOfExactType<DashboardScreen>();

    return Consumer<SiteProvider>(
      builder: (context, siteProvider, child) {
        final stats = siteProvider.getSiteStatistics();
        final totalSites = stats['total'] ?? 0;

        return Column(
          children: [
            Text('My Sites', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _ActionCard(
                  title: 'My Sites',
                  subtitle: 'Manage your websites',
                  icon: Icons.web_asset,
                  color: Colors.blue,
                  count: totalSites,
                  onTap: () {
                    // Use callback if available, otherwise do nothing
                    dashboardScreen?.onNavigateToSites?.call();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    final monitoringService = MonitoringService();
    final linkCheckerService = LinkCheckerService();

    return Consumer<SiteProvider>(
      builder: (context, siteProvider, child) {
        // サイトが1つもない場合はプレースホルダーを表示
        if (siteProvider.sites.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.timeline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No activity yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        // 最初のサイトの最新結果を取得
        final site = siteProvider.sites.first;

        return FutureBuilder<(MonitoringResult?, LinkCheckResult?)>(
          future:
              Future.wait([
                monitoringService.getLatestResult(site.id),
                linkCheckerService.getLatestCheckResult(site.id),
              ]).then(
                (results) => (
                  results[0] as MonitoringResult?,
                  results[1] as LinkCheckResult?,
                ),
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final monitoringResult = snapshot.data?.$1;
            final linkCheckResult = snapshot.data?.$2;

            // 両方の結果がない場合
            if (monitoringResult == null && linkCheckResult == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No checks performed yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Site Check結果
                    if (monitoringResult != null) ...[
                      _ActivityItem(
                        icon: monitoringResult.isUp
                            ? Icons.check_circle
                            : Icons.error,
                        iconColor: monitoringResult.isUp
                            ? Colors.green
                            : Colors.red,
                        title: 'Latest Site Check',
                        subtitle:
                            '${site.name} - ${monitoringResult.isUp ? "Up" : "Down"}',
                        timestamp: monitoringResult.timestamp,
                        details:
                            '${monitoringResult.statusCode} (${monitoringResult.responseTime}ms)',
                      ),
                      if (linkCheckResult != null) const Divider(height: 24),
                    ],

                    // Link Check結果
                    if (linkCheckResult != null) ...[
                      _ActivityItem(
                        icon: linkCheckResult.brokenLinks == 0
                            ? Icons.link
                            : Icons.link_off,
                        iconColor: linkCheckResult.brokenLinks == 0
                            ? Colors.blue
                            : Colors.orange,
                        title: 'Latest Link Check',
                        subtitle: site.name,
                        timestamp: linkCheckResult.timestamp,
                        details: linkCheckResult.brokenLinks == 0
                            ? '${linkCheckResult.totalLinks} links checked - All OK'
                            : '${linkCheckResult.brokenLinks}/${linkCheckResult.totalLinks} broken links',
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Recent Activity Item Widget
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String details;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.details,
  });

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          _formatTimestamp(timestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
