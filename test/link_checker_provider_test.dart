import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/utils/url_utils.dart';

void main() {
  group('UrlUtils - URL Mismatch Detection', () {
    test('detects no mismatch when URLs are identical', () {
      final site = Site(
        id: 'site_1',
        userId: 'user_1',
        name: 'Test Site',
        url: 'https://example.com',
        sitemapUrl: 'https://example.com/sitemap.xml',
        createdAt: DateTime.now(),
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
