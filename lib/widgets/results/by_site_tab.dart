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
        DateFormatter.formatRelativeTime(result.timestamp),
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
}
