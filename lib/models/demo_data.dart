import 'package:sitecat/models/site.dart';
import 'package:sitecat/models/monitoring_result.dart';
import 'package:sitecat/models/broken_link.dart';

/// Demo data for testing without authentication
class DemoData {
  static const String demoUserId = 'demo_user';

  /// Get demo sites
  static List<Site> getDemoSites() {
    final now = DateTime.now();
    return [
      Site(
        id: 'demo_site_1',
        userId: demoUserId,
        url: 'https://example.com',
        name: 'Example Domain',
        monitoringEnabled: true,
        checkInterval: 60,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        lastChecked: now.subtract(const Duration(hours: 1)),
        sitemapUrl: 'https://example.com/sitemap.xml',
        lastScannedPageIndex: 5,
      ),
      Site(
        id: 'demo_site_2',
        userId: demoUserId,
        url: 'https://flutter.dev',
        name: 'Flutter Official',
        monitoringEnabled: true,
        checkInterval: 30,
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(hours: 3)),
        lastChecked: now.subtract(const Duration(minutes: 45)),
        sitemapUrl: 'https://flutter.dev/sitemap.xml',
        lastScannedPageIndex: 10,
      ),
      Site(
        id: 'demo_site_3',
        userId: demoUserId,
        url: 'https://github.com',
        name: 'GitHub',
        monitoringEnabled: true,
        checkInterval: 120,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(hours: 5)),
        lastChecked: now.subtract(const Duration(hours: 2)),
        sitemapUrl: 'https://github.com/sitemap.xml',
        lastScannedPageIndex: 0,
      ),
      Site(
        id: 'demo_site_4',
        userId: demoUserId,
        url: 'https://apple.com',
        name: 'Apple Inc.',
        monitoringEnabled: false,
        checkInterval: 60,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 1)),
        lastChecked: now.subtract(const Duration(days: 1)),
        sitemapUrl: 'https://www.apple.com/sitemap.xml',
        lastScannedPageIndex: 3,
      ),
    ];
  }

  /// Get demo monitoring results for a site
  static List<MonitoringResult> getDemoMonitoringResults(String siteId) {
    final now = DateTime.now();
    final results = <MonitoringResult>[];

    // Generate 24 hours of monitoring data (hourly checks)
    for (int i = 0; i < 24; i++) {
      final timestamp = now.subtract(Duration(hours: i));
      final isUp = i % 10 != 3; // Simulate occasional downtime
      results.add(
        MonitoringResult(
          id: 'demo_monitoring_${siteId}_$i',
          siteId: siteId,
          userId: demoUserId,
          timestamp: timestamp,
          statusCode: isUp ? 200 : 503,
          responseTime: isUp ? 120 + (i * 10) : 0,
          isUp: isUp,
          error: isUp ? null : 'Service Unavailable',
        ),
      );
    }

    return results;
  }

  /// Get demo broken links for a site
  static List<BrokenLink> getDemoBrokenLinks(String siteId) {
    final now = DateTime.now();

    // Generate broken links based on site
    if (siteId == 'demo_site_1') {
      // Example.com has fewer broken links
      return [
        BrokenLink(
          id: 'demo_broken_1',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(hours: 1)),
          url: 'https://example.com/old-page',
          foundOn: 'https://example.com/index.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
        BrokenLink(
          id: 'demo_broken_2',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(hours: 1)),
          url: 'https://external-site.example/missing',
          foundOn: 'https://example.com/links.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.external,
        ),
      ];
    } else if (siteId == 'demo_site_2') {
      // Flutter.dev has some broken links
      return [
        BrokenLink(
          id: 'demo_broken_3',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(minutes: 45)),
          url: 'https://flutter.dev/deprecated-api',
          foundOn: 'https://flutter.dev/docs',
          statusCode: 410,
          error: 'Gone',
          linkType: LinkType.internal,
        ),
        BrokenLink(
          id: 'demo_broken_4',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(minutes: 45)),
          url: 'https://flutter.dev/old-tutorial',
          foundOn: 'https://flutter.dev/tutorials',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
        BrokenLink(
          id: 'demo_broken_5',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(minutes: 45)),
          url: 'https://broken-cdn.example.com/asset.js',
          foundOn: 'https://flutter.dev/examples',
          statusCode: 0,
          error: 'Connection timeout',
          linkType: LinkType.external,
        ),
      ];
    } else if (siteId == 'demo_site_3') {
      // GitHub has 1 broken link
      return [
        BrokenLink(
          id: 'demo_broken_6',
          siteId: siteId,
          userId: demoUserId,
          timestamp: now.subtract(const Duration(hours: 2)),
          url: 'https://github.com/deleted-repo',
          foundOn: 'https://github.com/explore',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];
    }

    // Apple.com has no broken links
    return [];
  }

  /// Get demo link check results for a site
  static List<LinkCheckResult> getDemoLinkCheckResults(String siteId) {
    final now = DateTime.now();

    if (siteId == 'demo_site_1') {
      return [
        LinkCheckResult(
          id: 'demo_check_1',
          siteId: siteId,
          checkedUrl: 'https://example.com',
          checkedSitemapUrl: 'https://example.com/sitemap.xml',
          sitemapStatusCode: 200,
          timestamp: now.subtract(const Duration(hours: 1)),
          totalLinks: 25,
          brokenLinks: 2,
          internalLinks: 18,
          externalLinks: 7,
          scanDuration: const Duration(seconds: 45),
          pagesScanned: 5,
          totalPagesInSitemap: 5,
          scanCompleted: true,
          newLastScannedPageIndex: 5,
        ),
      ];
    } else if (siteId == 'demo_site_2') {
      return [
        LinkCheckResult(
          id: 'demo_check_2',
          siteId: siteId,
          checkedUrl: 'https://flutter.dev',
          checkedSitemapUrl: 'https://flutter.dev/sitemap.xml',
          sitemapStatusCode: 404,
          timestamp: now.subtract(const Duration(minutes: 45)),
          totalLinks: 150,
          brokenLinks: 3,
          internalLinks: 120,
          externalLinks: 30,
          scanDuration: const Duration(minutes: 5, seconds: 30),
          pagesScanned: 10,
          totalPagesInSitemap: 50,
          scanCompleted: false,
          newLastScannedPageIndex: 10,
        ),
      ];
    } else if (siteId == 'demo_site_3') {
      return [
        LinkCheckResult(
          id: 'demo_check_3',
          siteId: siteId,
          checkedUrl: 'https://github.com',
          checkedSitemapUrl: 'https://github.com/sitemap.xml',
          sitemapStatusCode: 200,
          timestamp: now.subtract(const Duration(hours: 2)),
          totalLinks: 80,
          brokenLinks: 1,
          internalLinks: 65,
          externalLinks: 15,
          scanDuration: const Duration(minutes: 2),
          pagesScanned: 0,
          totalPagesInSitemap: 0,
          scanCompleted: true,
          newLastScannedPageIndex: 0,
        ),
      ];
    } else if (siteId == 'demo_site_4') {
      return [
        LinkCheckResult(
          id: 'demo_check_4',
          siteId: siteId,
          checkedUrl: 'https://apple.com',
          checkedSitemapUrl: 'https://www.apple.com/sitemap.xml',
          sitemapStatusCode: null,
          timestamp: now.subtract(const Duration(days: 1)),
          totalLinks: 200,
          brokenLinks: 0,
          internalLinks: 180,
          externalLinks: 20,
          scanDuration: const Duration(minutes: 8),
          pagesScanned: 3,
          totalPagesInSitemap: 100,
          scanCompleted: false,
          newLastScannedPageIndex: 3,
        ),
      ];
    }

    return [];
  }
}
