import 'package:flutter/material.dart';
import '../../models/site.dart';
import '../../models/broken_link.dart';
import '../../screens/site_detail_screen.dart';
import '../../utils/date_formatter.dart';

/// Card widget displaying link check result in Dashboard
class DashboardResultCard extends StatelessWidget {
  final Site site;
  final LinkCheckResult result;

  const DashboardResultCard({
    super.key,
    required this.site,
    required this.result,
  });

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
                color: hasIssues
                    ? Colors.orange.shade700
                    : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormatter.formatRelativeTime(result.timestamp),
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
