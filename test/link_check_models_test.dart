import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/models/broken_link.dart';

/// Link Check機能のモデル層テスト
/// Firestoreに依存しない、Pure Dartモデルのテスト
void main() {
  group('Progressive Scan - Site Model Tests', () {
    test('Site stores lastScannedPageIndex for progressive scan', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        url: 'https://example.com',
        name: 'Test Site',
        monitoringEnabled: true,
        checkInterval: 60,
        createdAt: DateTime.now(),
        lastScannedPageIndex: 50,
      );

      expect(site.lastScannedPageIndex, equals(50));
    });

    test('Site.copyWith updates lastScannedPageIndex', () {
      final original = Site(
        id: 'site_1',
        userId: 'user_1',
        url: 'https://example.com',
        name: 'Test Site',
        monitoringEnabled: true,
        checkInterval: 60,
        createdAt: DateTime.now(),
        lastScannedPageIndex: 0,
      );

      final updated = original.copyWith(lastScannedPageIndex: 100);

      expect(updated.lastScannedPageIndex, equals(100));
      expect(original.lastScannedPageIndex, equals(0)); // Original unchanged
    });

    test('default lastScannedPageIndex is 0', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        url: 'https://example.com',
        name: 'Test Site',
        monitoringEnabled: true,
        checkInterval: 60,
        createdAt: DateTime.now(),
      );

      expect(site.lastScannedPageIndex, equals(0));
    });
  });

  group('Progressive Scan - LinkCheckResult Tests', () {
    test('creates complete scan result', () {
      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime(2025, 10, 29, 12, 0),
        totalLinks: 753,
        brokenLinks: 2,
        internalLinks: 236,
        externalLinks: 45,
        scanDuration: const Duration(minutes: 5),
        pagesScanned: 236,
        totalPagesInSitemap: 236,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(result.siteId, equals('site_1'));
      expect(result.checkedUrl, equals('https://example.com'));
      expect(result.totalLinks, equals(753));
      expect(result.brokenLinks, equals(2));
      expect(result.pagesScanned, equals(236));
      expect(result.totalPagesInSitemap, equals(236));
      expect(result.scanCompleted, isTrue);
      expect(result.newLastScannedPageIndex, equals(0));
    });

    test('creates partial scan result', () {
      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 150,
        brokenLinks: 1,
        internalLinks: 50,
        externalLinks: 10,
        scanDuration: const Duration(minutes: 2),
        pagesScanned: 50,
        totalPagesInSitemap: 236,
        scanCompleted: false,
        newLastScannedPageIndex: 50,
      );

      expect(result.scanCompleted, isFalse);
      expect(result.pagesScanned, equals(50));
      expect(result.totalPagesInSitemap, equals(236));
      expect(result.newLastScannedPageIndex, equals(50));
    });

    test('completed scan resets lastScannedPageIndex to 0', () {
      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 753,
        brokenLinks: 2,
        internalLinks: 236,
        externalLinks: 45,
        scanDuration: const Duration(minutes: 5),
        pagesScanned: 236,
        totalPagesInSitemap: 236,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      expect(result.scanCompleted, isTrue);
      expect(result.newLastScannedPageIndex, equals(0));
    });

    test('partial scan keeps non-zero lastScannedPageIndex', () {
      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime.now(),
        totalLinks: 300,
        brokenLinks: 1,
        internalLinks: 100,
        externalLinks: 20,
        scanDuration: const Duration(minutes: 3),
        pagesScanned: 100,
        totalPagesInSitemap: 236,
        scanCompleted: false,
        newLastScannedPageIndex: 100,
      );

      expect(result.scanCompleted, isFalse);
      expect(result.newLastScannedPageIndex, equals(100));
    });

    test('converts LinkCheckResult to Firestore format', () {
      final result = LinkCheckResult(
        siteId: 'site_1',
        checkedUrl: 'https://example.com',
        timestamp: DateTime(2025, 10, 29, 12, 0),
        totalLinks: 753,
        brokenLinks: 2,
        internalLinks: 236,
        externalLinks: 45,
        scanDuration: const Duration(minutes: 5),
        pagesScanned: 236,
        totalPagesInSitemap: 236,
        scanCompleted: true,
        newLastScannedPageIndex: 0,
      );

      final firestore = result.toFirestore();

      expect(firestore['siteId'], equals('site_1'));
      expect(firestore['checkedUrl'], equals('https://example.com'));
      expect(firestore['totalLinks'], equals(753));
      expect(firestore['brokenLinks'], equals(2));
      expect(firestore['scanCompleted'], isTrue);
      expect(firestore['pagesScanned'], equals(236));
      expect(firestore['totalPagesInSitemap'], equals(236));
      expect(firestore['newLastScannedPageIndex'], equals(0));
    });
  });

  group('BrokenLink Model Tests', () {
    test('creates internal broken link', () {
      final link = BrokenLink(
        id: 'link_1',
        siteId: 'site_1',
        userId: 'user_1',
        timestamp: DateTime(2025, 10, 29, 12, 0),
        url: 'https://example.com/broken',
        foundOn: 'https://example.com/page1',
        statusCode: 404,
        error: 'Not Found',
        linkType: LinkType.internal,
      );

      expect(link.id, equals('link_1'));
      expect(link.siteId, equals('site_1'));
      expect(link.url, equals('https://example.com/broken'));
      expect(link.foundOn, equals('https://example.com/page1'));
      expect(link.statusCode, equals(404));
      expect(link.error, equals('Not Found'));
      expect(link.linkType, equals(LinkType.internal));
    });

    test('creates external broken link', () {
      final link = BrokenLink(
        id: 'link_2',
        siteId: 'site_1',
        userId: 'user_1',
        timestamp: DateTime.now(),
        url: 'https://external.com/broken',
        foundOn: 'https://example.com/page2',
        statusCode: 500,
        error: 'Internal Server Error',
        linkType: LinkType.external,
      );

      expect(link.linkType, equals(LinkType.external));
      expect(link.statusCode, equals(500));
    });

    test('converts BrokenLink to Firestore format', () {
      final link = BrokenLink(
        id: 'link_1',
        siteId: 'site_1',
        userId: 'user_1',
        timestamp: DateTime(2025, 10, 29, 12, 0),
        url: 'https://example.com/broken',
        foundOn: 'https://example.com/page1',
        statusCode: 404,
        error: 'Not Found',
        linkType: LinkType.external,
      );

      final firestore = link.toFirestore();

      expect(firestore['siteId'], equals('site_1'));
      expect(firestore['userId'], equals('user_1'));
      expect(firestore['url'], equals('https://example.com/broken'));
      expect(firestore['foundOn'], equals('https://example.com/page1'));
      expect(firestore['statusCode'], equals(404));
      expect(firestore['error'], equals('Not Found'));
      expect(firestore['linkType'], equals('external'));
    });

    test('broken link without error message', () {
      final link = BrokenLink(
        id: 'link_3',
        siteId: 'site_1',
        userId: 'user_1',
        timestamp: DateTime.now(),
        url: 'https://example.com/timeout',
        foundOn: 'https://example.com/page3',
        statusCode: 0,
        linkType: LinkType.internal,
      );

      expect(link.error, isNull);
      expect(link.statusCode, equals(0));
    });
  });

  group('Scan Progress Logic Tests', () {
    test('50 pages per chunk calculation', () {
      const totalPages = 236;
      const chunkSize = 50;

      // First chunk: 0-50
      var startIndex = 0;
      var endIndex = (startIndex + chunkSize).clamp(0, totalPages);
      expect(endIndex, equals(50));
      expect(endIndex < totalPages, isTrue); // Not completed

      // Second chunk: 50-100
      startIndex = 50;
      endIndex = (startIndex + chunkSize).clamp(0, totalPages);
      expect(endIndex, equals(100));
      expect(endIndex < totalPages, isTrue); // Not completed

      // Last chunk: 200-236
      startIndex = 200;
      endIndex = (startIndex + chunkSize).clamp(0, totalPages);
      expect(endIndex, equals(236));
      expect(endIndex == totalPages, isTrue); // Completed!
    });

    test('cumulative statistics calculation', () {
      // Scenario: 3 progressive scans
      const scan1TotalLinks = 150;
      const scan2TotalLinks = 160;
      const scan3TotalLinks = 143;

      // After first scan (0-50 pages)
      var cumulative = scan1TotalLinks;
      expect(cumulative, equals(150));

      // After second scan (50-100 pages)
      cumulative += scan2TotalLinks;
      expect(cumulative, equals(310));

      // After third scan (100-150 pages)
      cumulative += scan3TotalLinks;
      expect(cumulative, equals(453));
    });
  });
}
