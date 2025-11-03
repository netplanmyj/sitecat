import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
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
}
