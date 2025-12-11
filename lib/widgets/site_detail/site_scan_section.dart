import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/site_provider.dart';
import '../countdown_timer.dart';

class SiteScanSection extends StatefulWidget {
  final Site site;
  final Function(bool checkExternalLinks) onSiteScan;
  final VoidCallback onContinueScan;

  const SiteScanSection({
    super.key,
    required this.site,
    required this.onSiteScan,
    required this.onContinueScan,
  });

  @override
  State<SiteScanSection> createState() => _SiteScanSectionState();
}

class _SiteScanSectionState extends State<SiteScanSection> {
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

            // Get real-time progress during scan
            final (currentChecked, currentTotal) = linkCheckerProvider
                .getProgress(widget.site.id);

            // Calculate display values: prefer live totals during scan, fall back to cached
            final isFreshScanStarting = isCheckingLinks && currentTotal == 0;
            final progressTotal = isFreshScanStarting
                ? 0
                : (currentTotal > 0
                      ? currentTotal
                      : latestResult?.totalPagesInSitemap ?? 0);
            final progressChecked = isCheckingLinks
                ? currentChecked
                : currentSite.lastScannedPageIndex;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Site Scan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (timeUntilNext != null && timeUntilNext.inSeconds > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          border: Border.all(color: Colors.orange.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CountdownTimer(
                          initialDuration: timeUntilNext,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                          onComplete: () {
                            // Force UI refresh when countdown completes
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

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
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 8),

                // Site scan button and Continue scan button
                Row(
                  children: [
                    // Site scan / Stop button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isCheckingLinks
                            ? () =>
                                  linkCheckerProvider.cancelScan(widget.site.id)
                            : (canCheckLinks
                                  ? () => widget.onSiteScan(_checkExternalLinks)
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
                        // Continue is disabled when:
                        // - Currently scanning (isCheckingLinks)
                        // - No previous scan exists (lastScannedPageIndex == 0)
                        // - Scan is fully completed (scanCompleted == true)
                        // - In cooldown window (!canCheckLinks)
                        final isContinueDisabled =
                            isCheckingLinks ||
                            currentSite.lastScannedPageIndex == 0 ||
                            (latestResult?.scanCompleted ?? false) ||
                            !canCheckLinks;

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
                if ((currentSite.lastScannedPageIndex > 0 ||
                        isCheckingLinks ||
                        currentTotal > 0 ||
                        currentChecked > 0) &&
                    (latestResult != null || currentTotal > 0)) ...[
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
                          value: progressTotal > 0
                              ? (isCheckingLinks
                                        ? progressChecked
                                        : currentSite.lastScannedPageIndex) /
                                    progressTotal
                              : 0,
                          backgroundColor: Colors.blue.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${isCheckingLinks ? progressChecked : currentSite.lastScannedPageIndex} / $progressTotal pages scanned',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (!(latestResult?.scanCompleted ?? false))
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
}
