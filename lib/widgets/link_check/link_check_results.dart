import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import 'link_stat_card.dart';
import 'url_mismatch_warning.dart';
import '../../utils/url_utils.dart';

/// Widget to display link check results summary
class LinkCheckResults extends StatelessWidget {
  final LinkCheckResult result;
  final Site site;
  final List<BrokenLink> brokenLinks;
  final VoidCallback onViewBrokenLinks;
  final VoidCallback onDeleteResult;

  const LinkCheckResults({
    super.key,
    required this.result,
    required this.site,
    required this.brokenLinks,
    required this.onViewBrokenLinks,
    required this.onDeleteResult,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        // URL mismatch warning
        if (UrlUtils.hasUrlMismatch(result.checkedUrl, site.url)) ...[
          UrlMismatchWarning(
            checkedUrl: result.checkedUrl,
            currentUrl: site.url,
          ),
          const SizedBox(height: 12),
        ],

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

        // Delete result button
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onDeleteResult,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete This Result'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ),
      ],
    );
  }
}
