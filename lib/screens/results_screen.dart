import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/link_checker_provider.dart';
import '../providers/site_provider.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import 'broken_links_screen.dart';

/// Results screen with tabs for [All Results] and [By Site]
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkCheckerProvider>().loadAllCheckHistory(limit: 50);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Results', icon: Icon(Icons.list)),
            Tab(text: 'By Site', icon: Icon(Icons.web)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_AllResultsTab(), _BySiteTab()],
      ),
    );
  }
}

/// Tab 1: All Results (chronological order)
class _AllResultsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<LinkCheckerProvider, SiteProvider>(
      builder: (context, linkChecker, siteProvider, child) {
        final allResults = linkChecker.getAllCheckHistory();

        if (allResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No results yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run a full scan to see results',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allResults.length,
          itemBuilder: (context, index) {
            final item = allResults[index];
            final site = siteProvider.sites.firstWhere(
              (s) => s.id == item.siteId,
              orElse: () => Site(
                id: item.siteId,
                userId: '',
                url: 'Unknown',
                name: 'Unknown Site',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            return _buildResultCard(context, item.result, site, linkChecker);
          },
        );
      },
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    LinkCheckResult result,
    Site site,
    LinkCheckerProvider linkChecker,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          // Load broken links and navigate
          final brokenLinks = await linkChecker.getBrokenLinksForResult(
            site.id,
            result.id!,
          );
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrokenLinksScreen(
                  site: site,
                  brokenLinks: brokenLinks,
                  result: result,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site name and status
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          site.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    result.scanCompleted
                        ? Icons.check_circle
                        : Icons.incomplete_circle,
                    color: result.scanCompleted ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.link,
                    '${result.totalLinks}',
                    'Links',
                    Colors.blue,
                  ),
                  _buildStatItem(
                    Icons.link_off,
                    '${result.brokenLinks}',
                    'Broken',
                    result.brokenLinks > 0 ? Colors.red : Colors.green,
                  ),
                  _buildStatItem(
                    Icons.description,
                    '${result.pagesScanned}/${result.totalPagesInSitemap}',
                    'Pages',
                    result.scanCompleted ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Timestamp
              Text(
                _formatTimestamp(result.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Tab 2: By Site (grouped by site)
class _BySiteTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<LinkCheckerProvider, SiteProvider>(
      builder: (context, linkChecker, siteProvider, child) {
        final sites = siteProvider.sites;

        if (sites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.web, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No sites yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a site to see results',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sites.length,
          itemBuilder: (context, index) {
            final site = sites[index];
            final history = linkChecker.getCheckHistory(site.id);

            return _buildSiteGroup(context, site, history, linkChecker);
          },
        );
      },
    );
  }

  Widget _buildSiteGroup(
    BuildContext context,
    Site site,
    List<LinkCheckResult> history,
    LinkCheckerProvider linkChecker,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${history.length} result${history.length != 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: history.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No results yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ]
            : history
                  .map(
                    (result) =>
                        _buildHistoryItem(context, result, site, linkChecker),
                  )
                  .toList(),
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    LinkCheckResult result,
    Site site,
    LinkCheckerProvider linkChecker,
  ) {
    return ListTile(
      leading: Icon(
        result.scanCompleted ? Icons.check_circle : Icons.incomplete_circle,
        color: result.scanCompleted ? Colors.green : Colors.orange,
      ),
      title: Text(
        '${result.pagesScanned} pages • ${result.brokenLinks} broken',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        _formatTimestamp(result.timestamp),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () async {
        final brokenLinks = await linkChecker.getBrokenLinksForResult(
          site.id,
          result.id!,
        );
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrokenLinksScreen(
                site: site,
                brokenLinks: brokenLinks,
                result: result,
              ),
            ),
          );
        }
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
