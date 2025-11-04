import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../providers/monitoring_provider.dart';
import '../providers/link_checker_provider.dart';
import '../providers/site_provider.dart';
import '../widgets/site_info_card.dart';
import '../widgets/link_check_section.dart';
import '../widgets/monitoring_result_card.dart';
import '../widgets/countdown_timer.dart';
import 'broken_links_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;

  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  bool _checkExternalLinks = false;

  @override
  void initState() {
    super.initState();
    // Start listening to monitoring results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().listenToSiteResults(widget.site.id);
      // Load latest link check result
      context.read<LinkCheckerProvider>().loadLatestResult(widget.site.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.site.name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteInfoCard(site: widget.site),
              const SizedBox(height: 16),

              // Quick Check section
              _buildQuickCheckSection(),
              const SizedBox(height: 16),
              MonitoringResultCard(site: widget.site),

              const SizedBox(height: 24),

              // Full Scan section
              _buildFullScanSection(),
              const SizedBox(height: 16),
              LinkCheckSection(
                site: widget.site,
                onCheckComplete: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link check completed'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onCheckError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                onViewBrokenLinks: (site, brokenLinks, result) {
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCheckSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<MonitoringProvider>(
          builder: (context, monitoringProvider, child) {
            final isCheckingSite = monitoringProvider.isChecking(
              widget.site.id,
            );
            final canCheckSite = monitoringProvider.canCheckSite(
              widget.site.id,
            );
            final timeUntilNext = monitoringProvider.getTimeUntilNextCheck(
              widget.site.id,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Quick Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '⚡ Site status only (~3 seconds)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Quick Check button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (isCheckingSite || !canCheckSite)
                        ? null
                        : () => _quickCheck(),
                    icon: isCheckingSite
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.speed, size: 20),
                    label: const Text('Start Check'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Countdown timer (rate limit for checks)
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullScanSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer2<MonitoringProvider, LinkCheckerProvider>(
          builder: (context, monitoringProvider, linkCheckerProvider, child) {
            final isCheckingSite = monitoringProvider.isChecking(
              widget.site.id,
            );
            final canCheckSite = monitoringProvider.canCheckSite(
              widget.site.id,
            );
            final isCheckingLinks = linkCheckerProvider.isChecking(
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
                  onChanged: isCheckingSite || isCheckingLinks
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
                        onPressed:
                            (isCheckingSite || isCheckingLinks || !canCheckSite)
                            ? null
                            : () => _fullScan(),
                        icon: (isCheckingSite || isCheckingLinks)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search, size: 20),
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
                          onPressed: (isCheckingSite || isCheckingLinks)
                              ? null
                              : () => _continueScan(),
                          icon: isCheckingLinks
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                )
                              : const Icon(Icons.play_arrow, size: 20),
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

  Future<void> _quickCheck() async {
    final provider = context.read<MonitoringProvider>();
    await provider.checkSite(widget.site);

    if (!mounted) return;

    // Check for provider error first
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
      return;
    }

    // Check the actual result for errors (statusCode 0 or error message)
    final results = provider.getSiteResults(widget.site.id);
    if (results.isNotEmpty) {
      final latestResult = results.first;
      if (!latestResult.isUp || latestResult.error != null) {
        final errorMsg =
            latestResult.error ??
            'Site check failed (Status: ${latestResult.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Quick check completed'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fullScan() async {
    // Step 1: Run site check first
    final monitoringProvider = context.read<MonitoringProvider>();
    await monitoringProvider.checkSite(widget.site);

    if (!mounted) return;

    // Check for provider error first
    if (monitoringProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Site check failed: ${monitoringProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check the actual result for errors
    final results = monitoringProvider.getSiteResults(widget.site.id);
    if (results.isNotEmpty) {
      final latestResult = results.first;
      if (!latestResult.isUp || latestResult.error != null) {
        // Site check failed - show warning but continue with link check
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: ${latestResult.error ?? 'Site check failed (Status: ${latestResult.statusCode})'}\n'
              'Continuing with link check...',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // Run link check directly (no confirmation dialog needed)
    await _runLinkCheck(continueFromLastScan: false);
  }

  Future<void> _continueScan() async {
    // Get updated site data with the latest lastScannedPageIndex
    final siteProvider = context.read<SiteProvider>();
    final updatedSite = siteProvider.sites.firstWhere(
      (s) => s.id == widget.site.id,
      orElse: () => widget.site,
    );

    await _runLinkCheck(continueFromLastScan: true, site: updatedSite);
  }

  Future<void> _runLinkCheck({
    required bool continueFromLastScan,
    Site? site,
  }) async {
    final linkCheckerProvider = context.read<LinkCheckerProvider>();
    final targetSite = site ?? widget.site;

    try {
      await linkCheckerProvider.checkSiteLinks(
        targetSite,
        checkExternalLinks: _checkExternalLinks,
        continueFromLastScan: continueFromLastScan,
      );

      if (!mounted) return;

      final error = linkCheckerProvider.getError(widget.site.id);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link check error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        final result = linkCheckerProvider.getCachedResult(widget.site.id);
        final brokenCount = result?.brokenLinks ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              brokenCount == 0
                  ? '✓ Link scan complete - No broken links found!'
                  : '⚠️ Link scan complete - Found $brokenCount broken link${brokenCount > 1 ? 's' : ''}',
            ),
            backgroundColor: brokenCount == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
