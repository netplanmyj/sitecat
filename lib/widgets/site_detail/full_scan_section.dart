import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
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
        child: Consumer<LinkCheckerProvider>(
          builder: (context, linkCheckerProvider, child) {
            final isCheckingLinks = linkCheckerProvider.isChecking(
              widget.site.id,
            );
            final canCheckLinks = linkCheckerProvider.canCheckSite(
              widget.site.id,
            );
            final timeUntilNext = linkCheckerProvider.getTimeUntilNextCheck(
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

                    // Continue scan button (only if previous scan was incomplete)
                    if (linkCheckerProvider
                            .getCachedResult(widget.site.id)
                            ?.scanCompleted ==
                        false) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isCheckingLinks
                              ? null
                              : widget.onContinueScan,
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text('Continue'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: Colors.orange,
                            side: const BorderSide(
                              color: Colors.orange,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

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
                  'Note: Free plan scans up to 50 pages per check',
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
