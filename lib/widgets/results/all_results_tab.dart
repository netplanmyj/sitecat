import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/site_provider.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/common/empty_state.dart';
import '../../screens/broken_links_screen.dart';

class AllResultsTab extends StatelessWidget {
  const AllResultsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LinkCheckerProvider, SiteProvider>(
      builder: (context, linkChecker, siteProvider, child) {
        final allResults = linkChecker.getAllCheckHistory();

        if (allResults.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.assessment,
                title: 'No results yet',
                subtitle: 'Run a full scan to see results',
              ),
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
                DateFormatter.formatRelativeTime(result.timestamp),
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
}
