import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart';

void main() {
  group('LinkCheckHistoryScreen Statistics Calculations', () {
    test('calculates total checks correctly', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 0),
        _createLinkCheckResult(brokenLinks: 5),
        _createLinkCheckResult(brokenLinks: 2),
      ];

      final totalChecks = history.length;

      expect(totalChecks, 3);
    });

    test('counts completed scans correctly', () {
      final history = [
        _createLinkCheckResult(scanCompleted: true),
        _createLinkCheckResult(scanCompleted: true),
        _createLinkCheckResult(scanCompleted: false), // Partial scan
        _createLinkCheckResult(scanCompleted: true),
        _createLinkCheckResult(scanCompleted: false), // Partial scan
      ];

      final completedScans = history.where((r) => r.scanCompleted).length;

      expect(completedScans, 3);
    });

    test('calculates total broken links across all checks', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 5),
        _createLinkCheckResult(brokenLinks: 3),
        _createLinkCheckResult(brokenLinks: 0),
        _createLinkCheckResult(brokenLinks: 10),
        _createLinkCheckResult(brokenLinks: 2),
      ];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );

      expect(totalBrokenLinks, 20); // 5 + 3 + 0 + 10 + 2
    });

    test('calculates average broken links correctly', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 10),
        _createLinkCheckResult(brokenLinks: 20),
        _createLinkCheckResult(brokenLinks: 30),
      ];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;

      expect(avgBrokenLinks, 20.0);
    });

    test('calculates average broken links with decimal precision', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 5),
        _createLinkCheckResult(brokenLinks: 3),
        _createLinkCheckResult(brokenLinks: 4),
      ];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;
      final avgString = avgBrokenLinks.toStringAsFixed(1);

      expect(avgString, '4.0');
    });

    test('handles zero broken links correctly', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 0),
        _createLinkCheckResult(brokenLinks: 0),
        _createLinkCheckResult(brokenLinks: 0),
      ];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;

      expect(totalBrokenLinks, 0);
      expect(avgBrokenLinks, 0.0);
    });

    test('handles empty history gracefully', () {
      final history = <LinkCheckResult>[];

      final totalChecks = history.length;
      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalChecks > 0
          ? totalBrokenLinks / totalChecks
          : 0.0;

      expect(totalChecks, 0);
      expect(totalBrokenLinks, 0);
      expect(avgBrokenLinks, 0.0);
    });

    test('handles single check result', () {
      final history = [_createLinkCheckResult(brokenLinks: 7)];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;

      expect(totalBrokenLinks, 7);
      expect(avgBrokenLinks, 7.0);
    });

    test('calculates statistics for mixed complete and partial scans', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 10, scanCompleted: true),
        _createLinkCheckResult(brokenLinks: 5, scanCompleted: false),
        _createLinkCheckResult(brokenLinks: 0, scanCompleted: true),
        _createLinkCheckResult(brokenLinks: 3, scanCompleted: false),
      ];

      final totalChecks = history.length;
      final completedScans = history.where((r) => r.scanCompleted).length;
      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;

      expect(totalChecks, 4);
      expect(completedScans, 2);
      expect(totalBrokenLinks, 18);
      expect(avgBrokenLinks, 4.5);
    });

    test('formats average broken links to one decimal place', () {
      final history = [
        _createLinkCheckResult(brokenLinks: 7),
        _createLinkCheckResult(brokenLinks: 8),
        _createLinkCheckResult(brokenLinks: 9),
      ];

      final totalBrokenLinks = history.fold<int>(
        0,
        (sum, r) => sum + r.brokenLinks,
      );
      final avgBrokenLinks = totalBrokenLinks / history.length;
      final avgString = avgBrokenLinks.toStringAsFixed(1);

      expect(avgString, '8.0');
    });

    test('identifies partial scans correctly', () {
      final result = _createLinkCheckResult(
        pagesScanned: 25,
        totalPagesInSitemap: 50,
        scanCompleted: false,
      );

      expect(result.scanCompleted, false);
      expect(result.pagesScanned, lessThan(result.totalPagesInSitemap));
    });

    test('identifies complete scans correctly', () {
      final result = _createLinkCheckResult(
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
      );

      expect(result.scanCompleted, true);
      expect(result.pagesScanned, result.totalPagesInSitemap);
    });
  });

  group('LinkCheckResult Properties', () {
    test('creates valid LinkCheckResult with all fields', () {
      final result = LinkCheckResult(
        id: 'test-id',
        siteId: 'site-123',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 100,
        brokenLinks: 5,
        internalLinks: 80,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 5),
        pagesScanned: 50,
        totalPagesInSitemap: 50,
        scanCompleted: true,
        newLastScannedPageIndex: 50,
      );

      expect(result.totalLinks, 100);
      expect(result.brokenLinks, 5);
      expect(result.internalLinks, 80);
      expect(result.externalLinks, 20);
      expect(result.scanCompleted, true);
    });

    test('verifies link type breakdown', () {
      final result = _createLinkCheckResult(
        totalLinks: 100,
        internalLinks: 75,
        externalLinks: 25,
      );

      expect(result.internalLinks + result.externalLinks, result.totalLinks);
    });

    test('handles zero broken links scenario', () {
      final result = _createLinkCheckResult(totalLinks: 50, brokenLinks: 0);

      expect(result.brokenLinks, 0);
      expect(result.totalLinks, greaterThan(0));
    });

    test('handles all links broken scenario', () {
      final result = _createLinkCheckResult(totalLinks: 10, brokenLinks: 10);

      expect(result.brokenLinks, result.totalLinks);
    });
  });
}

// Helper function to create LinkCheckResult for testing
LinkCheckResult _createLinkCheckResult({
  int brokenLinks = 0,
  bool scanCompleted = true,
  int totalLinks = 100,
  int internalLinks = 80,
  int externalLinks = 20,
  int pagesScanned = 50,
  int totalPagesInSitemap = 50,
}) {
  return LinkCheckResult(
    id: 'test-${DateTime.now().millisecondsSinceEpoch}',
    siteId: 'test-site',
    checkedUrl: 'https://example.com',
    sitemapStatusCode: 200,
    timestamp: DateTime.now(),
    totalLinks: totalLinks,
    brokenLinks: brokenLinks,
    internalLinks: internalLinks,
    externalLinks: externalLinks,
    scanDuration: const Duration(minutes: 5),
    pagesScanned: pagesScanned,
    totalPagesInSitemap: totalPagesInSitemap,
    scanCompleted: scanCompleted,
    newLastScannedPageIndex: pagesScanned,
  );
}
