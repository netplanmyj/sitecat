import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/broken_link.dart';
import '../providers/link_checker_provider.dart';
import '../providers/site_provider.dart';
import '../utils/url_utils.dart';

/// Widget for link checking section
class LinkCheckSection extends StatefulWidget {
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
  State<LinkCheckSection> createState() => _LinkCheckSectionState();
}

class _LinkCheckSectionState extends State<LinkCheckSection> {
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkChecker, child) {
        final state = linkChecker.getCheckState(widget.site.id);
        final result = linkChecker.getCachedResult(widget.site.id);
        final (checked, total) = linkChecker.getProgress(widget.site.id);
        final brokenLinks = linkChecker.getCachedBrokenLinks(widget.site.id);
        final canCheck = linkChecker.canCheckSite(widget.site.id);
        final timeUntilNext = linkChecker.getTimeUntilNextCheck(widget.site.id);

        // Determine if we should show Continue Scan button
        final showContinueScan = result != null && !result.scanCompleted;

        // Start countdown timer if needed
        if (timeUntilNext != null && _countdownTimer == null) {
          _startCountdownTimer();
        } else if (timeUntilNext == null) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link_off, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Link Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (state == LinkCheckState.checking)
                      Text(
                        '$checked / $total',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      )
                    else if (result != null) ...[
                      Text(
                        '${result.pagesScanned} / ${result.totalPagesInSitemap}',
                        style: TextStyle(
                          fontSize: 14,
                          color: result.scanCompleted
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete result button
                      if (result.id != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete this result',
                          onPressed: () => _confirmDeleteResult(
                            context,
                            linkChecker,
                            widget.site.id,
                            result.id!,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Check/Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        state == LinkCheckState.checking ||
                            (!canCheck && !showContinueScan)
                        ? null
                        : () => showContinueScan
                              ? _continueScan(context)
                              : _checkLinks(context),
                    icon: state == LinkCheckState.checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            showContinueScan ? Icons.play_arrow : Icons.search,
                          ),
                    label: Text(
                      state == LinkCheckState.checking
                          ? 'Checking...'
                          : showContinueScan
                          ? 'Continue Scan'
                          : 'Check Links',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: showContinueScan
                          ? Colors.green
                          : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Cooldown timer (only show for new scans, not for continue)
                if (timeUntilNext != null && !showContinueScan) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Next check available in: ${timeUntilNext.inMinutes}:${(timeUntilNext.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],

                // Progress indicator
                if (state == LinkCheckState.checking) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: total > 0 ? checked / total : null,
                  ),
                ],

                // Results summary
                if (result != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // URL mismatch warning
                  if (UrlUtils.hasUrlMismatch(
                    result.checkedUrl,
                    widget.site.url,
                  )) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'URL Mismatch Detected',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This result was checked for a different URL:',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Checked: ${result.checkedUrl}',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  'Current: ${widget.site.url}',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Scan completion status (info only, no button)
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
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                          ),
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

                  Row(
                    children: [
                      Expanded(
                        child: _buildLinkStatCard(
                          'Total Links',
                          result.totalLinks.toString(),
                          Icons.link,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLinkStatCard(
                          'Broken',
                          result.brokenLinks.toString(),
                          Icons.link_off,
                          result.brokenLinks > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLinkStatCard(
                          'Pages',
                          '${result.pagesScanned}/${result.totalPagesInSitemap}',
                          Icons.description,
                          result.scanCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLinkStatCard(
                          'External',
                          result.externalLinks.toString(),
                          Icons.open_in_new,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  if (brokenLinks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => widget.onViewBrokenLinks(
                        widget.site,
                        brokenLinks,
                        result,
                      ),
                      icon: const Icon(Icons.list),
                      label: const Text('View Broken Links'),
                    ),
                  ],
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
                            linkChecker.getError(widget.site.id) ??
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

  Widget _buildLinkStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLinks(BuildContext context) async {
    final linkChecker = context.read<LinkCheckerProvider>();

    try {
      await linkChecker.checkSiteLinks(widget.site);
      widget.onCheckComplete();
    } catch (e) {
      widget.onCheckError(e.toString());
    }
  }

  Future<void> _continueScan(BuildContext context) async {
    final linkChecker = context.read<LinkCheckerProvider>();
    final siteProvider = context.read<SiteProvider>();

    try {
      // Get the latest site data to ensure we have the updated lastScannedPageIndex
      final latestSite = siteProvider.getSite(widget.site.id);
      if (latestSite == null) {
        throw Exception('Site not found');
      }

      await linkChecker.checkSiteLinks(latestSite, continueFromLastScan: true);
      widget.onCheckComplete();
    } catch (e) {
      widget.onCheckError(e.toString());
    }
  }

  Future<void> _confirmDeleteResult(
    BuildContext context,
    LinkCheckerProvider linkChecker,
    String siteId,
    String resultId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Result'),
        content: const Text(
          'Are you sure you want to delete this link check result? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await linkChecker.deleteLinkCheckResult(siteId, resultId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Result deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete result: $e')),
          );
        }
      }
    }
  }
}
