import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/monitoring_result.dart';
import '../providers/monitoring_provider.dart';
import '../providers/link_checker_provider.dart';
import '../providers/site_provider.dart';
import '../widgets/site_info_card.dart';
import '../widgets/link_check_section.dart';
import '../widgets/site_detail/full_scan_section.dart';
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
          // Site Scan Tab (integrated Full Scan with sitemap status)
          _buildFullScanTab(),
        ],
      ),
    );
  }

  // Full Scan Tab (Site Scan)
  Widget _buildFullScanTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SiteInfoCard(site: widget.site),
            const SizedBox(height: 16),
            // Sitemap Status Section (Quick Scan equivalent)
            _buildSitemapStatusSection(),
            const SizedBox(height: 16),
            FullScanSection(
              site: widget.site,
              onFullScan: (checkExternalLinks) {
                setState(() {
                  _checkExternalLinks = checkExternalLinks;
                });
                _fullScan();
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

  Future<void> _fullScan() async {
    try {
      // Full Scan uses LinkCheckerProvider only (no MonitoringProvider)
      // This ensures independent countdown timers for Quick Check and Full Scan
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

  /// Build Sitemap Status Section (integrated Quick Scan)
  Widget _buildSitemapStatusSection() {
    return Consumer<MonitoringProvider>(
      builder: (context, monitoringProvider, child) {
        final isChecking = monitoringProvider.isChecking(widget.site.id);
        final canCheck = monitoringProvider.canCheckSite(widget.site.id);
        final latestResult = monitoringProvider.getLatestResult(widget.site.id);
        final cachedStatusCode = monitoringProvider.getCachedSitemapStatus(
          widget.site.id,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Sitemap Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: isChecking || !canCheck ? null : _quickCheck,
                      tooltip: 'Refresh sitemap status',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isChecking)
                  const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (latestResult != null)
                  _buildSitemapStatusContent(latestResult, cachedStatusCode)
                else
                  const Text(
                    'No status check yet',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build sitemap status display content
  Widget _buildSitemapStatusContent(
    MonitoringResult result,
    int? cachedStatusCode,
  ) {
    final statusCode = cachedStatusCode ?? result.sitemapStatusCode;
    String statusText;
    Color statusColor;

    if (statusCode == null) {
      statusText = 'Not checked';
      statusColor = Colors.grey;
    } else if (statusCode == 200) {
      statusText = '✓ Sitemap found (200 OK)';
      statusColor = Colors.green;
    } else if (statusCode == 404) {
      statusText = '✗ Sitemap not found (404)';
      statusColor = Colors.red;
    } else if (statusCode == 0) {
      statusText = '✗ Network error';
      statusColor = Colors.red;
    } else {
      statusText = 'Status: $statusCode';
      statusColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusText,
          style: TextStyle(
            fontSize: 16,
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Last checked: ${result.timestamp.toString().split('.')[0]}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
