import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../providers/monitoring_provider.dart';
import '../providers/link_checker_provider.dart';
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
  @override
  void initState() {
    super.initState();
    // Start listening to monitoring results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().listenToSiteResults(widget.site.id);
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
              _buildCheckButton(),
              const SizedBox(height: 16),
              MonitoringResultCard(site: widget.site),
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

  Widget _buildCheckButton() {
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
            final timeUntilNext = monitoringProvider.getTimeUntilNextCheck(
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
                    Icon(Icons.monitor_heart, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Health Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose your check type:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                // Quick Check and Full Scan buttons
                Row(
                  children: [
                    // Quick Check button
                    Expanded(
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
                        label: const Text('Quick Check'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Full Scan button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            (isCheckingSite || isCheckingLinks || !canCheckSite)
                            ? null
                            : () => _fullScan(),
                        icon: (isCheckingSite || isCheckingLinks)
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : const Icon(Icons.search, size: 20),
                        label: const Text('Full Scan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.blue,
                          side: const BorderSide(
                            color: Colors.blue,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Info text
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '⚡ Quick: Site status only',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🔍 Full: Site + all links',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (timeUntilNext != null) ...[
                  const SizedBox(height: 12),
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

  Future<void> _quickCheck() async {
    final provider = context.read<MonitoringProvider>();
    await provider.checkSite(widget.site);

    if (!mounted) return;

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Quick check completed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fullScan() async {
    // Step 1: Run site check first
    final monitoringProvider = context.read<MonitoringProvider>();
    await monitoringProvider.checkSite(widget.site);

    if (!mounted) return;

    if (monitoringProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Site check failed: ${monitoringProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Step 2: Show result and ask if user wants to continue with link check
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Site Check Complete'),
          ],
        ),
        content: const Text(
          'Site is responding correctly.\n\n'
          'Continue with full link scan?\n'
          '(This may take a few minutes)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip Link Check'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.link_outlined),
            label: const Text('Start Link Scan'),
          ),
        ],
      ),
    );

    if (shouldContinue != true || !mounted) return;

    // Step 3: Run link check
    final linkCheckerProvider = context.read<LinkCheckerProvider>();
    try {
      await linkCheckerProvider.checkSiteLinks(widget.site);

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
                  ? '✓ Full scan complete - No broken links found!'
                  : '⚠️ Full scan complete - Found $brokenCount broken link${brokenCount > 1 ? 's' : ''}',
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
