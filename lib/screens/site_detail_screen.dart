import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../providers/monitoring_provider.dart';
import '../providers/link_checker_provider.dart';
import '../providers/site_provider.dart';
import '../widgets/site_info_card.dart';
import '../widgets/link_check_section.dart';
import '../widgets/site_detail/site_scan_section.dart';
import 'broken_links_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;

  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _checkExternalLinks = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

    // Start listening to monitoring results and auto-trigger quick scan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().listenToSiteResults(widget.site.id);
      // Load latest link check result
      context.read<LinkCheckerProvider>().loadLatestResult(widget.site.id);
      // Auto-trigger quick scan to get fresh sitemap status
      context.read<MonitoringProvider>().checkSite(widget.site);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.name),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Site Scan', icon: Icon(Icons.link))],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Site Scan Tab (integrated sitemap status)
          _buildSiteScanTab(),
        ],
      ),
    );
  }

  // Site Scan Tab
  Widget _buildSiteScanTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<MonitoringProvider>(
              builder: (context, monitoring, child) {
                final latestResult = monitoring.getLatestResult(widget.site.id);
                return SiteInfoCard(
                  site: widget.site,
                  sitemapStatus: latestResult,
                  cachedSitemapStatusCode: monitoring.getCachedSitemapStatus(
                    widget.site.id,
                  ),
                  isCheckingSitemap: monitoring.isChecking(widget.site.id),
                  getTimeUntilNextCheck: () =>
                      monitoring.getTimeUntilNextCheck(widget.site.id),
                  onRefreshSitemap: () => _quickCheck(),
                );
              },
            ),
            const SizedBox(height: 16),
            SiteScanSection(
              site: widget.site,
              onSiteScan: (checkExternalLinks) {
                setState(() {
                  _checkExternalLinks = checkExternalLinks;
                });
                _siteScan();
              },
              onContinueScan: _continueScan,
            ),
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

  Future<void> _siteScan() async {
    try {
      // Site Scan uses LinkCheckerProvider only (no MonitoringProvider)
      // This ensures independent countdown timers for Quick Check and Site Scan
      await _runLinkCheck(continueFromLastScan: false);
    } catch (e) {
      // Error handling is done in _runLinkCheck
    }
  }

  Future<void> _continueScan() async {
    try {
      // Get updated site data with the latest lastScannedPageIndex
      final siteProvider = context.read<SiteProvider>();
      final updatedSite = siteProvider.sites.firstWhere(
        (s) => s.id == widget.site.id,
        orElse: () => widget.site,
      );

      await _runLinkCheck(continueFromLastScan: true, site: updatedSite);
    } catch (e) {
      // Error handling is done in _runLinkCheck
    }
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
