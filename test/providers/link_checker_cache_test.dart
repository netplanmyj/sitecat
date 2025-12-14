import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/providers/link_checker_cache.dart';

// Helper to create LinkCheckResult for tests
LinkCheckResult _createTestResult({
  required String id,
  required String siteId,
  int totalLinks = 100,
  int brokenLinks = 5,
  DateTime? timestamp,
}) {
  return LinkCheckResult(
    id: id,
    siteId: siteId,
    checkedUrl: 'https://example.com',
    timestamp: timestamp ?? DateTime.now(),
    totalLinks: totalLinks,
    brokenLinks: brokenLinks,
    internalLinks: totalLinks - brokenLinks,
    externalLinks: 0,
    scanDuration: const Duration(seconds: 30),
    pagesScanned: 10,
    totalPagesInSitemap: 10,
    scanCompleted: true,
    newLastScannedPageIndex: 0,
  );
}

// Helper to create BrokenLink for tests
BrokenLink _createTestBrokenLink({
  required String id,
  required String siteId,
  required String userId,
  required String url,
  DateTime? timestamp,
}) {
  return BrokenLink(
    id: id,
    siteId: siteId,
    userId: userId,
    timestamp: timestamp ?? DateTime.now(),
    url: url,
    foundOn: 'https://example.com/page',
    statusCode: 404,
    error: 'Not Found',
    linkType: LinkType.internal,
  );
}

void main() {
  late LinkCheckerCache cache;

  setUp(() {
    cache = LinkCheckerCache();
  });

  group('LinkCheckerCache', () {
    // Result Cache Tests
    group('Result Cache', () {
      test('saveResult saves and retrieves a result', () {
        const String siteId = 'site-1';
        final result = _createTestResult(id: 'check-1', siteId: siteId);

        cache.saveResult(siteId, result);

        final retrievedResult = cache.getResult(siteId);

        expect(retrievedResult, isNotNull);
        expect(retrievedResult?.id, result.id);
        expect(retrievedResult?.siteId, result.siteId);
      });

      test('getResult returns null for unknown site', () {
        const String siteId = 'unknown-site';

        final result = cache.getResult(siteId);

        expect(result, isNull);
      });

      test('deleteResult removes a cached result', () {
        const String siteId = 'site-1';
        const String resultId = 'check-1';
        final result = _createTestResult(id: resultId, siteId: siteId);

        cache.saveResult(siteId, result);
        expect(cache.getResult(siteId), isNotNull);

        cache.deleteResult(siteId, resultId);
        // After deletion, the cached result should be removed if it matches the resultId
        final resultAfterDelete = cache.getResult(siteId);
        expect(resultAfterDelete, isNull);
      });
    });

    // Broken Links Cache Tests
    group('Broken Links Cache', () {
      test('saveBrokenLinks saves and retrieves broken links', () {
        const String siteId = 'site-1';
        final brokenLinks = [
          _createTestBrokenLink(
            id: 'link-1',
            siteId: siteId,
            userId: 'user-1',
            url: 'https://example.com/broken',
          ),
          _createTestBrokenLink(
            id: 'link-2',
            siteId: siteId,
            userId: 'user-1',
            url: 'https://example.com/another-broken',
          ),
        ];

        cache.saveBrokenLinks(siteId, brokenLinks);

        final retrievedLinks = cache.getBrokenLinks(siteId);

        expect(retrievedLinks, hasLength(2));
        expect(retrievedLinks[0].id, 'link-1');
        expect(retrievedLinks[1].id, 'link-2');
      });

      test('getBrokenLinks returns empty list when no links cached', () {
        const String siteId = 'site-1';

        final brokenLinks = cache.getBrokenLinks(siteId);

        expect(brokenLinks, isEmpty);
      });
    });

    // History Tests
    group('History', () {
      test('addToHistory adds a result to history', () {
        const String siteId = 'site-1';
        final result = _createTestResult(id: 'check-1', siteId: siteId);

        cache.addToHistory(siteId, result);

        final history = cache.getHistory(siteId);

        expect(history, hasLength(1));
        expect(history.first.id, 'check-1');
      });

      test('getHistory respects limit parameter', () {
        const String siteId = 'site-1';
        for (int i = 0; i < 60; i++) {
          final result = _createTestResult(
            id: 'check-$i',
            siteId: siteId,
            brokenLinks: i,
          );
          cache.addToHistory(siteId, result);
        }

        final history = cache.getHistory(siteId, limit: 10);

        expect(history, hasLength(10));
      });

      test('getHistory returns most recent first', () {
        const String siteId = 'site-1';
        final result1 = _createTestResult(
          id: 'check-1',
          siteId: siteId,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          brokenLinks: 5,
        );
        final result2 = _createTestResult(
          id: 'check-2',
          siteId: siteId,
          totalLinks: 150,
          brokenLinks: 3,
        );

        cache.addToHistory(siteId, result1);
        cache.addToHistory(siteId, result2);

        final history = cache.getHistory(siteId);

        expect(history, hasLength(2));
        expect(history.first.id, 'check-2'); // Most recent first
      });

      test('getAllHistory returns results from all sites', () {
        final result1 = _createTestResult(id: 'check-1', siteId: 'site-1');
        final result2 = _createTestResult(id: 'check-2', siteId: 'site-2');

        cache.addToHistory('site-1', result1);
        cache.addToHistory('site-2', result2);

        final allHistory = cache.getAllHistory();

        expect(allHistory, hasLength(2));
      });
    });

    // Sitemap Status Tests
    group('Sitemap Status', () {
      test('setSitemapStatusCode saves and retrieves sitemap status', () {
        const String siteId = 'site-1';
        const int statusCode = 200;

        cache.setSitemapStatusCode(siteId, statusCode);

        final retrievedStatus = cache.getSitemapStatusCode(siteId);

        expect(retrievedStatus, statusCode);
      });

      test('getSitemapStatusCode returns null for unknown site', () {
        const String siteId = 'unknown-site';

        final statusCode = cache.getSitemapStatusCode(siteId);

        expect(statusCode, isNull);
      });
    });

    // Clear Cache Tests
    group('Clear Cache', () {
      test('clearCache removes result and broken links for a site', () {
        const String siteId = 'site-1';
        final result = _createTestResult(id: 'check-1', siteId: siteId);
        final brokenLinks = [
          _createTestBrokenLink(
            id: 'link-1',
            siteId: siteId,
            userId: 'user-1',
            url: 'https://example.com/broken',
          ),
        ];

        cache.saveResult(siteId, result);
        cache.saveBrokenLinks(siteId, brokenLinks);

        cache.clearCache(siteId);

        expect(cache.getResult(siteId), isNull);
        expect(cache.getBrokenLinks(siteId), isEmpty);
      });

      test('clearAllCaches removes all data', () {
        final result1 = _createTestResult(id: 'check-1', siteId: 'site-1');
        final result2 = _createTestResult(id: 'check-2', siteId: 'site-2');

        cache.saveResult('site-1', result1);
        cache.saveResult('site-2', result2);

        cache.clearAllCaches();

        expect(cache.getResult('site-1'), isNull);
        expect(cache.getResult('site-2'), isNull);
      });
    });

    // Cache Stats Tests
    group('Cache Stats', () {
      test('getCacheStats returns correct statistics', () {
        final result1 = _createTestResult(id: 'check-1', siteId: 'site-1');
        final result2 = _createTestResult(id: 'check-2', siteId: 'site-2');

        cache.saveResult('site-1', result1);
        cache.saveResult('site-2', result2);
        cache.addToHistory('site-1', result1);
        cache.setSitemapStatusCode('site-1', 200);

        final stats = cache.getCacheStats();

        expect(stats['resultCacheSize'], 2);
        expect(stats['checkHistorySize'], 1);
        expect(stats['sitemapStatusCodeSize'], 1);
      });
    });

    // setHistory and setAllHistory Tests
    group('Set History Methods', () {
      test(
        'setHistory replaces history atomically and syncs global history',
        () {
          const String siteId = 'site-1';
          final result1 = _createTestResult(id: 'check-1', siteId: siteId);
          final result2 = _createTestResult(id: 'check-2', siteId: siteId);
          final result3 = _createTestResult(id: 'check-3', siteId: siteId);

          // Add initial history
          cache.addToHistory(siteId, result1);

          // Set new history atomically
          cache.setHistory(siteId, [result2, result3]);

          final siteHistory = cache.getHistory(siteId);
          final globalHistory = cache.getAllHistory();

          // Check site history is replaced
          expect(siteHistory, hasLength(2));
          expect(siteHistory[0].id, 'check-2');
          expect(siteHistory[1].id, 'check-3');

          // Check global history is updated (should have only new entries)
          expect(globalHistory, hasLength(2));
          expect(
            globalHistory.where((item) => item.siteId == siteId),
            hasLength(2),
          );
        },
      );

      test('setAllHistory replaces global history atomically', () {
        final result1 = _createTestResult(id: 'check-1', siteId: 'site-1');
        final result2 = _createTestResult(id: 'check-2', siteId: 'site-2');
        final result3 = _createTestResult(id: 'check-3', siteId: 'site-3');

        cache.addToHistory('site-1', result1);
        cache.addToHistory('site-2', result2);

        // Set new global history atomically
        cache.setAllHistory([
          (siteId: 'site-1', checkResult: result1),
          (siteId: 'site-3', checkResult: result3),
        ]);

        final globalHistory = cache.getAllHistory();

        expect(globalHistory, hasLength(2));
        expect(globalHistory[0].siteId, 'site-1');
        expect(globalHistory[1].siteId, 'site-3');
      });
    });
  });
}
