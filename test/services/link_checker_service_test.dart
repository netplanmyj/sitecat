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
