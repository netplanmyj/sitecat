import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/broken_link.dart';
import '../providers/link_checker_provider.dart';
import 'link_check/link_check_progress.dart';
import 'link_check/full_scan_card.dart';

/// Widget for link check results display (read-only)
/// Link checking is initiated from the "Full Scan" button in the parent screen
class LinkCheckSection extends StatelessWidget {
  final Site site;
  final VoidCallback onCheckComplete;
  final Function(String error) onCheckError;
  final Function(
    Site site,
    List<BrokenLink> brokenLinks,
    LinkCheckResult result,
  )
  onViewBrokenLinks;

  const LinkCheckSection({
    super.key,
    required this.site,
    required this.onCheckComplete,
    required this.onCheckError,
    required this.onViewBrokenLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkChecker, _) {
        final state = linkChecker.getCheckState(site.id);
        final result = linkChecker.getCachedResult(site.id);
        final progress = linkChecker.getProgress(site.id);
        final externalLinksProgress = linkChecker.getExternalLinksProgress(
          site.id,
        );
        final isProcessingExternalLinks = linkChecker.isProcessingExternalLinks(
          site.id,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.link_outlined),
                    const SizedBox(width: 8),
                    const Text(
                      'Full Scan Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Progress indicator (when checking)
                if (state == LinkCheckState.checking) ...[
                  const SizedBox(height: 16),
                  LinkCheckProgress(
                    checked: progress.$1,
                    total: progress.$2,
                    isProcessingExternalLinks: isProcessingExternalLinks,
                    externalLinksChecked: externalLinksProgress.$1,
                    externalLinksTotal: externalLinksProgress.$2,
                  ),
                ],

                // Results (when available) - Use FullScanCard for consistency
                if (result != null) ...[
                  const SizedBox(height: 16),
                  FullScanCard(
                    site: site,
                    result: result,
                    onTap: () async {
                      final brokenLinks = await linkChecker
                          .getBrokenLinksForResult(site.id, result.id!);
                      if (context.mounted) {
                        onViewBrokenLinks(site, brokenLinks, result);
                      }
                    },
                  ),
                ],

                // No results yet
                if (result == null && state != LinkCheckState.checking) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No link check results yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use "Full Scan" above to check all links',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error message
                if (state == LinkCheckState.error) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            linkChecker.getError(site.id) ??
                                'An error occurred',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
