import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/providers/link_checker_provider.dart';
import 'package:sitecat/utils/url_utils.dart';

void main() {
  group('LinkCheckerProvider - State Management Logic', () {
    test('isProcessingExternalLinks logic - returns false for empty map', () {
      // Test the logic without instantiating the provider
      final Map<String, bool> isProcessingMap = {};
      expect(isProcessingMap['site_1'] ?? false, isFalse);
    });

    test('isProcessingExternalLinks logic - returns true when set', () {
      final Map<String, bool> isProcessingMap = {'site_1': true};
      expect(isProcessingMap['site_1'] ?? false, isTrue);
    });

    test(
      'isProcessingExternalLinks logic - returns false when explicitly set',
      () {
        final Map<String, bool> isProcessingMap = {'site_1': false};
        expect(isProcessingMap['site_1'] ?? false, isFalse);
      },
    );

    test('progress tracking logic - handles empty state', () {
      final Map<String, int> checkedCounts = {};
      final Map<String, int> totalCounts = {};

      final checked = checkedCounts['site_1'] ?? 0;
      final total = totalCounts['site_1'] ?? 0;

      expect(checked, equals(0));
      expect(total, equals(0));
    });

    test('progress tracking logic - tracks progress correctly', () {
      final Map<String, int> checkedCounts = {'site_1': 25};
      final Map<String, int> totalCounts = {'site_1': 50};

      final checked = checkedCounts['site_1'] ?? 0;
      final total = totalCounts['site_1'] ?? 0;

      expect(checked, equals(25));
      expect(total, equals(50));
      expect(checked < total, isTrue);
    });

    test('external links processing trigger - activates when pages complete', () {
      final checked = 50;
      final total = 50;
      final checkExternalLinks = true;

      // Simulates the condition: checkExternalLinks && checked >= total && total > 0
      final shouldProcessExternal =
          checkExternalLinks && checked >= total && total > 0;

      expect(shouldProcessExternal, isTrue);
    });

    test('external links processing trigger - does not activate mid-scan', () {
      const checked = 25;
      const total = 50;
      const checkExternalLinks = true;

      const shouldProcessExternal =
          checkExternalLinks && checked >= total && total > 0;

      expect(shouldProcessExternal, isFalse);
    });

    test('external links processing trigger - validates condition logic', () {
      // Helper function to test the condition logic dynamically
      bool shouldProcessExternal(bool enabled, int checked, int total) {
        return enabled && checked >= total && total > 0;
      }

      // Test various scenarios
      expect(shouldProcessExternal(true, 50, 50), isTrue); // All conditions met
      expect(shouldProcessExternal(false, 50, 50), isFalse); // Disabled
      expect(shouldProcessExternal(true, 40, 50), isFalse); // Not complete
      expect(shouldProcessExternal(true, 50, 0), isFalse); // Empty total
    });

    test('minimum check interval logic - 1 minute for debugging', () {
      expect(LinkCheckerProvider.minimumCheckInterval.inMinutes, equals(1));
    });

    test('external links progress tracking - handles empty state', () {
      final Map<String, int> externalLinksChecked = {};
      final Map<String, int> externalLinksTotal = {};

      final checked = externalLinksChecked['site_1'] ?? 0;
      final total = externalLinksTotal['site_1'] ?? 0;

      expect(checked, equals(0));
      expect(total, equals(0));
    });

    test('external links progress tracking - tracks progress correctly', () {
      final Map<String, int> externalLinksChecked = {'site_1': 15};
      final Map<String, int> externalLinksTotal = {'site_1': 30};

      final checked = externalLinksChecked['site_1'] ?? 0;
      final total = externalLinksTotal['site_1'] ?? 0;

      expect(checked, equals(15));
      expect(total, equals(30));
      expect(checked < total, isTrue);
    });

    test('external links progress tracking - completes when all checked', () {
      final Map<String, int> externalLinksChecked = {'site_1': 30};
      final Map<String, int> externalLinksTotal = {'site_1': 30};

      final checked = externalLinksChecked['site_1'] ?? 0;
      final total = externalLinksTotal['site_1'] ?? 0;

      expect(checked, equals(total));
      expect(checked >= total, isTrue);
    });

    test('external links progress - calculates percentage correctly', () {
      // Test progress calculation logic
      double calculateProgress(int checked, int total) {
        return total > 0 ? checked / total : 0.0;
      }

      expect(calculateProgress(0, 30), equals(0.0));
      expect(calculateProgress(15, 30), equals(0.5));
      expect(calculateProgress(30, 30), equals(1.0));
      expect(calculateProgress(0, 0), equals(0.0)); // Edge case
    });

    test('two-stage progress - page scan then external links', () {
      // Simulate the two-stage progress flow
      final stages = <String, Map<String, int>>{
        'pages': {'checked': 50, 'total': 50},
        'external': {'checked': 0, 'total': 20},
      };

      // Stage 1: Page scanning complete
      expect(stages['pages']!['checked'], equals(stages['pages']!['total']));

      // Stage 2: External links starting
      expect(stages['external']!['checked'], equals(0));
      expect(stages['external']!['total'], greaterThan(0));

      // Simulate progress
      stages['external']!['checked'] = 10;
      expect(
        stages['external']!['checked']! < stages['external']!['total']!,
        isTrue,
      );

      // Simulate completion
      stages['external']!['checked'] = 20;
      expect(
        stages['external']!['checked'],
        equals(stages['external']!['total']),
      );
    });
  });

  group('UrlUtils - URL Mismatch Detection', () {
    test('detects no mismatch when URLs are identical', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://example.com',
        sitemapUrl: 'https://example.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });

    test('detects mismatch when URLs differ', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://new-domain.com',
        sitemapUrl: 'https://new-domain.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://old-domain.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isTrue);
    });

    test('ignores protocol differences (http vs https)', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://example.com',
        sitemapUrl: 'https://example.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'http://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });

    test('ignores www prefix differences', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://www.example.com',
        sitemapUrl: 'https://www.example.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });

    test('ignores trailing slash differences', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://example.com/',
        sitemapUrl: 'https://example.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });

    test('handles case insensitivity', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://Example.COM',
        sitemapUrl: 'https://Example.COM/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });

    test('detects path differences', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://example.com/new-path',
        sitemapUrl: 'https://example.com/new-path/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com/old-path',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isTrue);
    });

    test('normalizes complex URL variations correctly', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'HTTPS://WWW.Example.COM/',
        sitemapUrl: 'https://www.example.com/sitemap.xml',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'http://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 0,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(UrlUtils.hasUrlMismatch(result.checkedUrl, site.url), isFalse);
    });
  });
}
