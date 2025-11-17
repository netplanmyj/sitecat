import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/site_provider.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/common/empty_state.dart';
import '../../screens/broken_links_screen.dart';

class BySiteTab extends StatelessWidget {
  const BySiteTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LinkCheckerProvider, SiteProvider>(
      builder: (context, linkChecker, siteProvider, child) {
        final sites = siteProvider.sites;

        if (sites.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.web,
                title: 'No sites yet',
                subtitle: 'Add a site to see results',
              ),
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
          hasIssues
              ? '${result.brokenLinks}/${result.totalLinks} broken links'
              : '${result.totalLinks} links checked - All OK',
          style: TextStyle(
            color: hasIssues ? Colors.orange.shade700 : Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${result.pagesScanned}/${result.totalPagesInSitemap} pages',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatRelativeTime(result.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
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
      ),
    );
  }
}
