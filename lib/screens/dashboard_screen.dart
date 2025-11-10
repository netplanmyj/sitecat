import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/site_provider.dart';
import '../providers/link_checker_provider.dart';
import '../models/site.dart';
import '../models/broken_link.dart';
import 'site_detail_screen.dart';

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
                _WelcomeCard(user: user),
                const SizedBox(height: 24),

                // My Sites Section
                _MySitesSection(
                  onNavigateToSites: onNavigateToSites,
                ),
                const SizedBox(height: 24),

                // Recent Activity Section
                _RecentActivitySection(
                  onNavigateToResults: onNavigateToResults,
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
  final VoidCallback? onNavigateToSites;

  const _MySitesSection({this.onNavigateToSites});

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteProvider>(
      builder: (context, siteProvider, child) {
        final sites = siteProvider.sites.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'My Sites',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),

            // Site cards (max 5)
            if (sites.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.web_asset,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sites added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sites.length,
                itemBuilder: (context, index) {
                  final site = sites[index];
                  return _SiteCard(site: site);
                },
              ),

            // All Sites button
            if (sites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onNavigateToSites,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      'All Sites (${siteProvider.sites.length})',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SiteCard extends StatelessWidget {
  final Site site;

  const _SiteCard({required this.site});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.language, color: Colors.blue.shade700),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              site.displayUrl,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Every ${site.checkIntervalDisplay}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SiteDetailScreen(site: site),
            ),
          );
        },
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final VoidCallback? onNavigateToResults;

  const _RecentActivitySection({this.onNavigateToResults});

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkCheckerProvider, child) {
        final allResults = linkCheckerProvider
            .getAllCheckHistory()
            .take(5)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),

            // Results list (max 5)
            if (allResults.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No scan results yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Consumer<SiteProvider>(
                builder: (context, siteProvider, child) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allResults.length,
                    itemBuilder: (context, index) {
                      final item = allResults[index];
                      final site = siteProvider.sites.firstWhere(
                        (s) => s.id == item.siteId,
                        orElse: () => Site(
                          id: item.siteId,
                          userId: '',
                          name: 'Unknown Site',
                          url: '',
                          checkInterval: 60,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                      return _ResultCard(
                        site: site,
                        result: item.result,
                      );
                    },
                  );
                },
              ),

            // All Results button
            if (allResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onNavigateToResults,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'All Results',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Site site;
  final LinkCheckResult result;

  const _ResultCard({
    required this.site,
    required this.result,
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
    final hasIssues = result.brokenLinks > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasIssues
              ? Colors.orange.shade100
              : Colors.green.shade100,
          child: Icon(
            hasIssues ? Icons.link_off : Icons.check_circle,
            color: hasIssues ? Colors.orange.shade700 : Colors.green.shade700,
          ),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasIssues
                  ? '${result.brokenLinks}/${result.totalLinks} broken links'
                  : '${result.totalLinks} links checked - All OK',
              style: TextStyle(
                color: hasIssues ? Colors.orange.shade700 : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(result.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SiteDetailScreen(site: site),
            ),
          );
        },
      ),
    );
  }
}
