import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/site_provider.dart';
import '../countdown_timer.dart';

class FullScanSection extends StatefulWidget {
  final Site site;
  final Function(bool checkExternalLinks) onFullScan;
  final VoidCallback onContinueScan;

  const FullScanSection({
    super.key,
    required this.site,
    required this.onFullScan,
    required this.onContinueScan,
  });

  @override
  State<FullScanSection> createState() => _FullScanSectionState();
}

class _FullScanSectionState extends State<FullScanSection> {
  bool _checkExternalLinks = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer2<LinkCheckerProvider, SiteProvider>(
          builder: (context, linkCheckerProvider, siteProvider, child) {
            // Get the latest site data from SiteProvider
            final currentSite = siteProvider.sites.firstWhere(
              (s) => s.id == widget.site.id,
              orElse: () => widget.site,
            );

            final isCheckingLinks = linkCheckerProvider.isChecking(
              widget.site.id,
            );
            final canCheckLinks = linkCheckerProvider.canCheckSite(
              widget.site.id,
            );
            final timeUntilNext = linkCheckerProvider.getTimeUntilNextCheck(
              widget.site.id,
            );

            // Get the latest scan result to show progress
            final latestResult = linkCheckerProvider.getCachedResult(
              widget.site.id,
            );

            // Get current sitemap status (updated during scan, or from latest result)
            final currentSitemapStatus =
                linkCheckerProvider.getCurrentSitemapStatusCode(
                  widget.site.id,
                ) ??
                latestResult?.sitemapStatusCode;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.link, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Full Scan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '🔍 Site status + all links check (may take several minutes)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Site and Sitemap status info
                if (currentSite.sitemapUrl != null &&
                    currentSite.sitemapUrl!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scan Configuration',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                          'Site URL',
                          currentSite.url,
                          null, // We don't check site URL status here
                        ),
                        const SizedBox(height: 6),
                        _buildStatusRow(
                          'Sitemap',
                          currentSite.sitemapUrl!,
                          currentSitemapStatus,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // External links checkbox
                CheckboxListTile(
                  value: _checkExternalLinks,
                  onChanged: isCheckingLinks
                      ? null
                      : (value) {
                          setState(() {
                            _checkExternalLinks = value ?? false;
                          });
                        },
                  title: const Text('Check external links'),
                  subtitle: const Text(
                    'Also check links to other domains (takes longer)',
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 8),

                // Full scan button and Continue scan button
                Row(
                  children: [
                    // Full scan / Stop button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCheckingLinks
                            ? () =>
                                  linkCheckerProvider.cancelScan(widget.site.id)
                            : (canCheckLinks
                                  ? () => widget.onFullScan(_checkExternalLinks)
                                  : null),
                        icon: Icon(
                          isCheckingLinks ? Icons.stop : Icons.search,
                          size: 20,
                        ),
                        label: Text(
                          isCheckingLinks ? 'Stop Scan' : 'Start Scan',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: isCheckingLinks
                              ? Colors.red
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Continue scan button (always visible, disabled if no previous scan)
                    Expanded(
                      child: (() {
                        final isContinueDisabled =
                            isCheckingLinks ||
                            !canCheckLinks ||
                            currentSite.lastScannedPageIndex == 0 ||
                            (latestResult?.scanCompleted ?? false);
                        return OutlinedButton.icon(
                          onPressed: isContinueDisabled
                              ? null
                              : widget.onContinueScan,
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text('Continue'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: isContinueDisabled
                                ? Colors.grey
                                : Colors.orange,
                            side: BorderSide(
                              color: isContinueDisabled
                                  ? Colors.grey
                                  : Colors.orange,
                              width: 1.5,
                            ),
                          ),
                        );
                      })(),
                    ),
                  ],
                ),

                // Progress indicator - show current scan progress when available
                if (currentSite.lastScannedPageIndex > 0 &&
                    latestResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scan Progress',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: latestResult.totalPagesInSitemap > 0
                              ? currentSite.lastScannedPageIndex /
                                    latestResult.totalPagesInSitemap
                              : 0,
                          backgroundColor: Colors.blue.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentSite.lastScannedPageIndex} / ${latestResult.totalPagesInSitemap} pages scanned',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (!latestResult.scanCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Use "Continue" to scan the remaining pages',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Countdown timer (rate limit for link checks)
                if (timeUntilNext != null) ...[
                  const SizedBox(height: 8),
                  CountdownTimer(
                    initialDuration: timeUntilNext,
                    onComplete: () {
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],

                const SizedBox(height: 8),

                // Note about page limit
                Text(
                  'Note: Scans up to 100 pages per batch',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String url, int? statusCode) {
    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (statusCode == null) {
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.help_outline;
      statusText = 'Not checked';
    } else if (statusCode == 0) {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.cloud_off;
      statusText = 'Network Error';
    } else if (statusCode == 200) {
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
      statusText = 'OK ($statusCode)';
    } else if (statusCode == 404) {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.cancel;
      statusText = 'Not Found (404)';
    } else if (statusCode >= 400 && statusCode < 500) {
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.error_outline;
      statusText = 'Error ($statusCode)';
    } else if (statusCode >= 500) {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.error;
      statusText = 'Server Error ($statusCode)';
    } else {
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.info_outline;
      statusText = 'Status: $statusCode';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                url,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statusCode != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
