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
                    // Full scan button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (isCheckingLinks || !canCheckLinks)
                            ? null
                            : () => widget.onFullScan(_checkExternalLinks),
                        icon: const Icon(Icons.search, size: 20),
                        label: const Text('Start Scan'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Continue scan button (always visible, disabled if no previous scan)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            (isCheckingLinks ||
                                currentSite.lastScannedPageIndex == 0 ||
                                (latestResult?.scanCompleted ?? false))
                            ? null
                            : widget.onContinueScan,
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text('Continue'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: currentSite.lastScannedPageIndex == 0
                              ? Colors.grey
                              : Colors.orange,
                          side: BorderSide(
                            color: currentSite.lastScannedPageIndex == 0
                                ? Colors.grey
                                : Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
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
}
