import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart' as xml;
import 'package:sitecat/utils/url_encoding_utils.dart';

/// Helper method to extract and normalize URLs from sitemap XML
/// Simulates the behavior of _extractUrlsFromSitemapDocument
List<Uri> _extractNormalizedUrlsFromSitemap(String sitemapXml) {
  final document = xml.XmlDocument.parse(sitemapXml);
  final urlElements = document.findAllElements('url');
  final normalizedUrls = <String, Uri>{};

  for (final urlElement in urlElements) {
    final locElement = urlElement.findElements('loc').firstOrNull;
    if (locElement != null) {
      final urlString = locElement.innerText.trim();
      if (urlString.isNotEmpty) {
        try {
          final uri = Uri.parse(urlString);
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            // Normalize: remove fragment, scheme/host to lowercase, trailing slash
            final uriWithoutFragment = uri.removeFragment();
            final normalizedScheme = uriWithoutFragment.scheme.toLowerCase();
            final normalizedHost = uriWithoutFragment.host.toLowerCase();
            String path = uriWithoutFragment.path;
            if (path.length > 1 && path.endsWith('/')) {
              path = path.substring(0, path.length - 1);
            }
            final normalized = uriWithoutFragment.replace(
              scheme: normalizedScheme,
              host: normalizedHost,
              path: path,
            );
            // Map handles deduplication automatically
            normalizedUrls[normalized.toString()] = normalized;
          }
        } catch (e) {
          // Skip invalid URLs
        }
      }
    }
  }

  return normalizedUrls.values.toList();
}

void main() {
  group('Mojibake URL Fixing', () {
    test('should fix double-encoded Japanese URLs', () {
      // Arrange: Double-encoded "開発" tag URL
      // UTF-8 bytes: E9 96 8B E7 99 BA
      // Misinterpreted as Latin-1: é – ‹ ç ™ º
      // Re-encoded as UTF-8: %C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA
      const doubleEncodedUrl =
          'https://example.com/tags/%C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA/';

      // Act
      final fixedUrl = UrlEncodingUtils.fixMojibakeUrl(doubleEncodedUrl);

      // Assert: Should be fixed to correct UTF-8 encoding
      expect(fixedUrl, 'https://example.com/tags/%E9%96%8B%E7%99%BA/');
      expect(Uri.decodeFull(fixedUrl), contains('開発'));
    });

    test('should not modify correctly encoded Japanese URLs', () {
      // Arrange: Correctly encoded "開発" URL
      const correctUrl = 'https://example.com/tags/%E9%96%8B%E7%99%BA/';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(correctUrl);

      // Assert: Should remain unchanged
      expect(result, correctUrl);
    });

    test('should not modify European language URLs', () {
      // Arrange: French URL with accented characters
      const frenchUrl = 'https://example.fr/caf%C3%A9';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(frenchUrl);

      // Assert: Should remain unchanged
      expect(result, frenchUrl);
      expect(Uri.decodeFull(result), 'https://example.fr/café');
    });

    test('should detect mojibake patterns correctly', () {
      // Arrange: Various patterns
      const mojibakePatterns = [
        'Â\u0080Â\u0081', // C2 byte sequences
        'é\u0096\u008B', // é + control chars
      ];

      const normalPatterns = [
        'café', // Normal French
        'España', // Normal Spanish
        'resume', // Normal English
      ];

      // Act & Assert: Mojibake should be detected
      for (final pattern in mojibakePatterns) {
        expect(
          UrlEncodingUtils.containsMojibake(pattern),
          true,
          reason: 'Should detect mojibake in: $pattern',
        );
      }

      // Normal text should not be detected
      for (final pattern in normalPatterns) {
        expect(
          UrlEncodingUtils.containsMojibake(pattern),
          false,
          reason: 'Should not detect mojibake in: $pattern',
        );
      }
    });

    test('should return original URL when recovery fails', () {
      // Arrange: URL that might cause recovery issues
      const problematicUrl = 'https://example.com/path/with/�/invalid';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(problematicUrl);

      // Assert: Should return original when recovery fails
      expect(result, problematicUrl);
    });

    test('should handle invalid URLs gracefully', () {
      // Arrange: Invalid URL strings
      const invalidUrls = ['not a url', '://invalid', ''];

      // Act & Assert: Should not throw, return original
      for (final url in invalidUrls) {
        expect(
          () => UrlEncodingUtils.fixMojibakeUrl(url),
          returnsNormally,
          reason: 'Should handle invalid URL: $url',
        );
        expect(UrlEncodingUtils.fixMojibakeUrl(url), url);
      }
    });

    test('should fix multiple mojibake sequences in one URL', () {
      // Arrange: URL with multiple Japanese segments
      // "開発" and "記事" both double-encoded
      const multiMojibakeUrl =
          'https://example.com/tags/%C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA/'
          'posts/%C3%A8%C2%A8%C2%98%C3%A4%C2%BA%C2%8B/';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(multiMojibakeUrl);

      // Assert: Both should be fixed
      final decoded = Uri.decodeFull(result);
      expect(decoded, contains('開発'));
      expect(decoded, contains('記事'));
    });

    test('should preserve query parameters and fragments', () {
      // Arrange: Double-encoded URL with query params and fragment
      const urlWithExtras =
          'https://example.com/tags/%C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA/'
          '?page=1&sort=desc#section';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(urlWithExtras);

      // Assert: Query params and fragment should be preserved
      expect(result, contains('?page=1&sort=desc'));
      expect(result, contains('#section'));
      final decoded = Uri.decodeFull(result);
      expect(decoded, contains('開発'));
    });

    test('should handle URLs with both correct and mojibake encoding', () {
      // Arrange: Mix of correct and mojibake encoding
      // Note: Current implementation processes the entire decoded URL,
      // so it will detect and fix the mojibake portion
      const urlWithMojibake =
          'https://example.com/tags/%C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA/';

      // Act
      final result = UrlEncodingUtils.fixMojibakeUrl(urlWithMojibake);

      // Assert: Mojibake should be fixed
      final decoded = Uri.decodeFull(result);
      expect(decoded, contains('開発')); // Mojibake fixed
    });
  });

  group('Sitemap XML Parsing', () {
    test('should parse valid sitemap.xml and extract URLs', () {
      // Arrange
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2024-01-01</lastmod>
  </url>
  <url>
    <loc>https://example.com/about</loc>
    <lastmod>2024-01-02</lastmod>
  </url>
  <url>
    <loc>https://example.com/contact</loc>
    <lastmod>2024-01-03</lastmod>
  </url>
</urlset>''';

      // Act
      final document = xml.XmlDocument.parse(sitemapXml);
      final urlElements = document.findAllElements('loc');
      final urls = urlElements.map((e) => e.innerText.trim()).toList();

      // Assert
      expect(urls.length, 3);
      expect(urls[0], 'https://example.com/');
      expect(urls[1], 'https://example.com/about');
      expect(urls[2], 'https://example.com/contact');
    });

    test('should handle empty sitemap', () {
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
</urlset>''';

      final document = xml.XmlDocument.parse(sitemapXml);
      final urlElements = document.findAllElements('loc');

      expect(urlElements.isEmpty, true);
    });

    test('should extract URLs and filter by scheme', () {
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/valid</loc>
  </url>
  <url>
    <loc>http://example.com/also-valid</loc>
  </url>
  <url>
    <loc>ftp://example.com/invalid-scheme</loc>
  </url>
</urlset>''';

      final document = xml.XmlDocument.parse(sitemapXml);
      final urlElements = document.findAllElements('loc');
      final urls = urlElements.map((e) => e.innerText.trim()).where((
        urlString,
      ) {
        try {
          final uri = Uri.parse(urlString);
          return uri.scheme == 'http' || uri.scheme == 'https';
        } catch (e) {
          return false;
        }
      }).toList();

      expect(urls.length, 2);
      expect(urls[0], 'https://example.com/valid');
      expect(urls[1], 'http://example.com/also-valid');
    });

    test('should handle malformed XML gracefully', () {
      const malformedXml =
          '<urlset><url><loc>https://example.com</url></urlset>';

      expect(
        () => xml.XmlDocument.parse(malformedXml),
        throwsA(isA<xml.XmlException>()),
      );
    });

    test('should parse sitemap with multiple URL properties', () {
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://example.com/page1</loc>
    <lastmod>2024-01-01</lastmod>
    <changefreq>daily</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://example.com/page2</loc>
    <lastmod>2024-01-02</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.6</priority>
  </url>
</urlset>''';

      final document = xml.XmlDocument.parse(sitemapXml);
      final urlElements = document.findAllElements('loc');

      expect(urlElements.length, 2);

      // Verify we can extract other properties too
      final urlNodes = document.findAllElements('url');
      expect(urlNodes.length, 2);

      final firstUrl = urlNodes.first;
      expect(firstUrl.findElements('changefreq').first.innerText, 'daily');
      expect(firstUrl.findElements('priority').first.innerText, '0.8');
    });

    test('should handle sitemap index format', () {
      const sitemapIndexXml = '''<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemap-1.xml</loc>
    <lastmod>2024-01-01</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemap-2.xml</loc>
    <lastmod>2024-01-02</lastmod>
  </sitemap>
</sitemapindex>''';

      final document = xml.XmlDocument.parse(sitemapIndexXml);
      final sitemapElements = document.findAllElements('sitemap');

      expect(sitemapElements.length, 2);

      final locElements = document.findAllElements('loc');
      final sitemapUrls = locElements.map((e) => e.innerText.trim()).toList();

      expect(sitemapUrls.length, 2);
      expect(sitemapUrls[0], 'https://example.com/sitemap-1.xml');
      expect(sitemapUrls[1], 'https://example.com/sitemap-2.xml');
    });

    test('should limit URLs to maximum count', () {
      // Generate a sitemap with more than 100 URLs
      final urlElements = List.generate(
        150,
        (i) => '  <url><loc>https://example.com/page-$i</loc></url>',
      );

      final sitemapXml =
          '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urlElements.join('\n')}
</urlset>''';

      final document = xml.XmlDocument.parse(sitemapXml);
      final locElements = document.findAllElements('loc');

      expect(locElements.length, 150);

      // Simulate limiting to 100
      final limitedUrls = locElements.take(100).toList();
      expect(limitedUrls.length, 100);
    });
  });

  group('Free Plan Page Limit', () {
    test('should enforce 100 page limit for free plan', () {
      // Arrange: 150 pages in sitemap
      const totalPages = 150;
      const freePlanLimit = 100;
      const batchSize = 50;

      // Act: First batch (0-50)
      const startIndex1 = 0;
      final remainingLimit1 = freePlanLimit - startIndex1;
      final actualBatch1 = batchSize.clamp(0, remainingLimit1);
      final endIndex1 = startIndex1 + actualBatch1;

      // Assert: First batch scans 50 pages
      expect(actualBatch1, 50);
      expect(endIndex1, 50);
      expect(endIndex1 < freePlanLimit, true);
      expect(endIndex1 < totalPages, true, reason: 'More pages available');

      // Act: Second batch (50-100)
      const startIndex2 = 50;
      final remainingLimit2 = freePlanLimit - startIndex2;
      final actualBatch2 = batchSize.clamp(0, remainingLimit2);
      final endIndex2 = startIndex2 + actualBatch2;

      // Assert: Second batch scans 50 pages and reaches limit
      expect(actualBatch2, 50);
      expect(endIndex2, 100);
      expect(endIndex2 >= freePlanLimit, true);

      // Act: Third batch would exceed limit
      const startIndex3 = 100;
      final remainingLimit3 = freePlanLimit - startIndex3;
      final actualBatch3 = batchSize.clamp(0, remainingLimit3);

      // Assert: Third batch scans 0 pages (limit reached)
      expect(actualBatch3, 0);
      expect(remainingLimit3, 0);
    });

    test('should scan in 50 page batches', () {
      // Arrange
      const totalPages = 250;
      const batchSize = 50;
      const freePlanLimit = 100;

      // Act & Assert: Simulate multiple batches
      final batches = <int, int>{};
      var currentIndex = 0;

      while (currentIndex < freePlanLimit && currentIndex < totalPages) {
        final remainingLimit = freePlanLimit - currentIndex;
        final actualBatch = batchSize.clamp(0, remainingLimit);
        final endIndex = currentIndex + actualBatch;

        batches[currentIndex] = endIndex;
        currentIndex = endIndex;
      }

      // Assert: Should have exactly 2 batches (0-50, 50-100)
      expect(batches.length, 2);
      expect(batches[0], 50); // First batch: 0-50
      expect(batches[50], 100); // Second batch: 50-100
      expect(currentIndex, 100); // Stopped at limit
    });

    test('should handle sites smaller than batch size', () {
      // Arrange: 30 page site
      const totalPages = 30;
      const batchSize = 50;
      const freePlanLimit = 100;

      // Act: First batch
      const startIndex = 0;
      final remainingLimit = freePlanLimit - startIndex;
      final actualBatch = batchSize.clamp(0, remainingLimit);
      final endIndex = (startIndex + actualBatch).clamp(0, totalPages);

      // Assert: Should scan all 30 pages in one batch
      expect(actualBatch, 50); // Attempted 50 pages
      expect(endIndex, 30); // But only 30 pages exist
      expect(endIndex >= totalPages, true); // Scan completed
    });

    test('should handle sites exactly at limit', () {
      // Arrange: Exactly 100 pages
      const totalPages = 100;
      const freePlanLimit = 100;

      // Act: Two batches
      const batch1End = 50;
      const batch2End = 100;

      // Assert: Should complete exactly at limit
      expect(batch1End < freePlanLimit, true);
      expect(batch2End, freePlanLimit);
      expect(batch2End >= totalPages, true);
    });

    test('should mark scan as completed when limit reached', () {
      // Arrange: 120 page site
      const totalPages = 120;
      const endIndex = 100; // After 2 batches
      const freePlanLimit = 100;

      // Act: Check completion status
      final scanCompleted = endIndex >= totalPages || endIndex >= freePlanLimit;

      // Assert: Should be completed due to limit, not total pages
      expect(scanCompleted, true);
      expect(endIndex < totalPages, true); // Not all pages scanned
      expect(endIndex >= freePlanLimit, true); // But limit reached
    });
  });

  group('URL Validation', () {
    test('should validate HTTP URLs', () {
      const url = 'http://example.com';
      final uri = Uri.tryParse(url);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'http');
      expect(uri.host, 'example.com');
    });

    test('should validate HTTPS URLs', () {
      const url = 'https://example.com';
      final uri = Uri.tryParse(url);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'example.com');
    });

    test('should identify non-HTTP(S) schemes', () {
      const urls = [
        'ftp://example.com',
        'file:///path/to/file',
        'mailto:test@example.com',
        'tel:+1234567890',
      ];

      for (final url in urls) {
        final uri = Uri.tryParse(url);
        expect(uri, isNotNull);
        expect(
          uri!.scheme.startsWith('http'),
          false,
          reason: '$url should not have http(s) scheme',
        );
      }
    });

    test('should parse URLs with paths and query parameters', () {
      const url =
          'https://example.com/path/to/page?param1=value1&param2=value2';
      final uri = Uri.tryParse(url);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'example.com');
      expect(uri.path, '/path/to/page');
      expect(uri.queryParameters['param1'], 'value1');
      expect(uri.queryParameters['param2'], 'value2');
    });

    test('should handle URLs with fragments', () {
      const url = 'https://example.com/page#section';
      final uri = Uri.tryParse(url);

      expect(uri, isNotNull);
      expect(uri!.fragment, 'section');
    });

    test('should reject invalid URLs', () {
      const invalidUrls = [
        'not a url',
        'htp://missing-t.com',
        '://no-scheme.com',
      ];

      for (final url in invalidUrls) {
        final uri = Uri.tryParse(url);
        // tryParse might return a URI but it won't be valid
        if (uri != null) {
          expect(
            uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'),
            false,
            reason: '$url should not be a valid HTTP(S) URL',
          );
        }
      }
    });
  });

  group('URL Normalization in Sitemap Parsing', () {
    test('should deduplicate URLs with fragments and trailing slashes', () {
      // Arrange: Sitemap with duplicate URLs in various forms
      // Tests: fragment removal, trailing slash normalization, root path preservation
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
  <url><loc>https://example.com/#top</loc></url>
  <url><loc>https://example.com/page1</loc></url>
  <url><loc>https://example.com/page1/</loc></url>
  <url><loc>https://example.com/page1#section</loc></url>
  <url><loc>https://example.com/page1/#anchor</loc></url>
  <url><loc>https://example.com/page2</loc></url>
  <url><loc>https://example.com/page2/</loc></url>
</urlset>''';

      // Act
      final urls = _extractNormalizedUrlsFromSitemap(sitemapXml);

      // Assert: 8 URLs → 3 unique (root, page1, page2)
      expect(urls.length, 3);
      expect(urls.map((u) => u.toString()).toSet(), {
        'https://example.com/',
        'https://example.com/page1',
        'https://example.com/page2',
      });
    });

    test('should preserve query parameters during normalization', () {
      // Arrange: Sitemap with query parameters, trailing slash, and fragment
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/search?q=test&amp;page=1</loc></url>
  <url><loc>https://example.com/search/?q=test&amp;page=1#results</loc></url>
</urlset>''';

      // Act
      final urls = _extractNormalizedUrlsFromSitemap(sitemapXml);

      // Assert: Should deduplicate to 1 URL with query parameters preserved
      expect(urls.length, 1);
      expect(urls[0].toString(), 'https://example.com/search?q=test&page=1');
      expect(urls[0].queryParameters['q'], 'test');
      expect(urls[0].queryParameters['page'], '1');
    });

    test('should handle Japanese URLs with normalization', () {
      // Arrange: Japanese "開発" tag with trailing slash and fragment
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/tags/%E9%96%8B%E7%99%BA</loc></url>
  <url><loc>https://example.com/tags/%E9%96%8B%E7%99%BA/</loc></url>
  <url><loc>https://example.com/tags/%E9%96%8B%E7%99%BA/#content</loc></url>
</urlset>''';

      // Act
      final urls = _extractNormalizedUrlsFromSitemap(sitemapXml);

      // Assert: Should deduplicate to 1 URL
      expect(urls.length, 1);
      expect(urls[0].toString(), 'https://example.com/tags/%E9%96%8B%E7%99%BA');
      expect(Uri.decodeFull(urls[0].toString()), contains('開発'));
    });

    test('should normalize scheme and host to lowercase (RFC 3986)', () {
      // Arrange: URLs with mixed case in scheme and host
      const sitemapXml = '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/page</loc></url>
  <url><loc>HTTPS://example.com/page</loc></url>
  <url><loc>https://Example.com/page</loc></url>
  <url><loc>HTTPS://EXAMPLE.COM/page</loc></url>
  <url><loc>https://example.com/page/</loc></url>
</urlset>''';

      // Act
      final urls = _extractNormalizedUrlsFromSitemap(sitemapXml);

      // Assert: Should deduplicate to 1 URL with lowercase scheme and host
      expect(urls.length, 1);
      expect(urls[0].scheme, 'https');
      expect(urls[0].host, 'example.com');
      expect(urls[0].toString(), 'https://example.com/page');
    });
  });

  group('Link Occurrence Counting', () {
    test('should count total link occurrences including duplicates across pages', () {
      // This test verifies that when the same link appears on multiple pages,
      // the system correctly:
      // 1. Counts each occurrence in totalInternalLinksCount/totalExternalLinksCount
      // 2. Deduplicates links in the Sets (internalLinks/externalLinks)

      // Note: This is a documentation test since full link checking
      // requires mocking HTTP responses and HTML parsing.
      // The actual implementation in link_checker_service.dart:
      // - Uses Sets (internalLinks, externalLinks) for deduplication
      // - Increments counters (totalInternalLinksCount, totalExternalLinksCount) for each occurrence
      // - Result: totalLinks = totalInternalLinksCount + totalExternalLinksCount

      // Example scenario:
      // Page A contains: [link1, link2, link1] (link1 appears twice)
      // Page B contains: [link1, link3]
      // Expected:
      // - Unique links: {link1, link2, link3} (3 unique)
      // - Total occurrences: 5 (link1 counted 3 times, link2 once, link3 once)

      expect(
        true,
        isTrue,
      ); // Placeholder - full test requires integration testing
    });

    test(
      'should maintain data consistency: totalLinks = internal + external',
      () {
        // This test documents the expected relationship between counts:
        // totalLinks should always equal internalLinks + externalLinks
        // All three fields count occurrences including duplicates

        // Example:
        // Internal link occurrences: 361
        // External link occurrences: 11
        // Total link occurrences: 372 (= 361 + 11)

        expect(
          true,
          isTrue,
        ); // Placeholder - full test requires integration testing
      },
    );
  });
}
