import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../screens/link_check_history_screen.dart';
import 'link_stat_card.dart';

/// Widget to display link check results summary
class LinkCheckResults extends StatelessWidget {
  final LinkCheckResult result;
  final Site site;
  final List<BrokenLink> brokenLinks;
  final VoidCallback onViewBrokenLinks;

  const LinkCheckResults({
    super.key,
    required this.result,
    required this.site,
    required this.brokenLinks,
    required this.onViewBrokenLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        // Timestamp
        Text(
          'Checked at: ${_formatTimestamp(result.timestamp)}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),

        // Scan completion status
        if (!result.scanCompleted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Partial scan: ${result.pagesScanned}/${result.totalPagesInSitemap} pages scanned',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Page limit notification (Phase 2: 将来追加予定)
        // if (result.pagesScanned >= AppConstants.freePlanPageLimit) ...[
        //   Container(
        //     padding: const EdgeInsets.all(12),
        //     decoration: BoxDecoration(
        //       color: Colors.blue.shade50,
        //       borderRadius: BorderRadius.circular(8),
        //       border: Border.all(color: Colors.blue.shade200),
        //     ),
        //     child: Row(
        //       children: [
        //         Icon(Icons.info, color: Colors.blue.shade700),
        //         const SizedBox(width: 8),
        //         Expanded(
        //           child: Text(
        //             '無料版は${AppConstants.freePlanPageLimit}ページまでスキャン可能です。',
        //             style: TextStyle(color: Colors.blue.shade900),
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        //   const SizedBox(height: 12),
        // ],

        // Statistics cards
        Row(
          children: [
            Expanded(
              child: LinkStatCard(
                label: 'Total Links',
                value: result.totalLinks.toString(),
                icon: Icons.link,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinkStatCard(
                label: 'Broken',
                value: result.brokenLinks.toString(),
                icon: Icons.link_off,
                color: result.brokenLinks > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinkStatCard(
                label: 'Pages',
                value: '${result.pagesScanned}/${result.totalPagesInSitemap}',
                icon: Icons.description,
                color: result.scanCompleted ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinkStatCard(
                label: 'External',
                value: result.externalLinks.toString(),
                icon: Icons.open_in_new,
                color: Colors.purple,
              ),
            ),
          ],
        ),

        // View broken links button
        if (brokenLinks.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewBrokenLinks,
              icon: const Icon(Icons.list_alt),
              label: Text('View Broken Links (${brokenLinks.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],

        // View history button
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LinkCheckHistoryScreen(site: site),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('View History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
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
