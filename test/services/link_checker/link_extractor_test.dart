import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/link_checker/link_extractor.dart';
import 'package:sitecat/services/link_checker/http_client.dart';
import 'package:sitecat/services/link_checker/sitemap_parser.dart';

/// Mock implementation of LinkCheckerHttpClient for testing
class MockLinkCheckerHttpClient implements LinkCheckerHttpClient {
  final Map<String, String?> _htmlContents = {};
  final Map<String, List<Uri>> _extractedLinks = {};

  void setHtmlContent(Uri uri, String? htmlContent) {
    _htmlContents[uri.toString()] = htmlContent;
  }

  void setExtractedLinks(Uri pageUri, List<Uri> links) {
    _extractedLinks[pageUri.toString()] = links;
  }

  @override
  Future<String?> fetchHtmlContent(String url) async {
    await Future.delayed(
      const Duration(milliseconds: 1),
    ); // Simulate network delay
    return _htmlContents[url];
  }

  @override
  List<Uri> extractLinks(String htmlContent, Uri baseUrl) {
    return _extractedLinks[baseUrl.toString()] ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock implementation of SitemapParser for testing
class MockSitemapParser implements SitemapParser {
  @override
  Uri normalizeSitemapUrl(Uri url) {
    // Simple normalization: remove trailing slash and fragment
    final pathSegments = url.pathSegments.where((s) => s.isNotEmpty).toList();
    return Uri(
      scheme: url.scheme,
      host: url.host,
      port: url.port == 80 || url.port == 443 ? null : url.port,
      pathSegments: pathSegments,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LinkExtractor', () {
    late MockLinkCheckerHttpClient mockHttpClient;
    late MockSitemapParser mockSitemapParser;
    late LinkExtractor extractor;

    setUp(() {
      mockHttpClient = MockLinkCheckerHttpClient();
      mockSitemapParser = MockSitemapParser();
      extractor = LinkExtractor(
        httpClient: mockHttpClient,
        sitemapParser: mockSitemapParser,
      );
    });

    group('scanPagesAndExtractLinks', () {
      test(
        'should extract internal and external links from single page',
        () async {
          // Arrange
          final baseUrl = Uri.parse('https://example.com');
          final page1 = Uri.parse('https://example.com/page1');

          final internalLink = Uri.parse('https://example.com/page2');
          final externalLink = Uri.parse('https://external.com/page');

          mockHttpClient.setHtmlContent(page1, '<html>mock content</html>');
          mockHttpClient.setExtractedLinks(page1, [internalLink, externalLink]);

          // Act
          final result = await extractor.scanPagesAndExtractLinks(
            pagesToScan: [page1],
            originalBaseUrl: baseUrl,
            startIndex: 0,
            totalPagesInSitemap: 1,
          );

          // Assert
          expect(result.internalLinks, contains(internalLink));
          expect(result.externalLinks, contains(externalLink));
          expect(result.pagesScanned, 1);
          expect(result.totalInternalLinksCount, 1);
          expect(result.totalExternalLinksCount, 1);
        },
      );

      test('should track link sources correctly', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');
        final page2 = Uri.parse('https://example.com/page2');
        final targetLink = Uri.parse('https://example.com/target');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setHtmlContent(page2, '<html>page2</html>');
        mockHttpClient.setExtractedLinks(page1, [targetLink]);
        mockHttpClient.setExtractedLinks(page2, [targetLink]);

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page2],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 2,
        );

        // Assert
        final normalizedTargetLink = mockSitemapParser.normalizeSitemapUrl(
          targetLink,
        );
        final sources = result.linkSourceMap[normalizedTargetLink.toString()];
        expect(sources, isNotNull);
        expect(sources, hasLength(2));
        expect(sources, contains(page1.toString()));
        expect(sources, contains(page2.toString()));
      });

      test('should skip pages that return null HTML content', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');
        final page2 = Uri.parse('https://example.com/page2');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setHtmlContent(page2, null); // Simulates fetch failure
        mockHttpClient.setExtractedLinks(page1, [
          Uri.parse('https://example.com/link1'),
        ]);

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page2],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 2,
        );

        // Assert
        expect(result.pagesScanned, 2); // Both pages visited
        expect(result.internalLinks, hasLength(1)); // Only page1's link
      });

      test('should not visit the same page twice', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');

        mockHttpClient.setHtmlContent(page1, '<html>content</html>');
        mockHttpClient.setExtractedLinks(page1, []);

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page1, page1], // Same page repeated
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 3,
        );

        // Assert
        expect(result.pagesScanned, 1); // Only scanned once
      });

      test('should call onProgress callback during scanning', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');
        final page2 = Uri.parse('https://example.com/page2');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setHtmlContent(page2, '<html>page2</html>');
        mockHttpClient.setExtractedLinks(page1, []);
        mockHttpClient.setExtractedLinks(page2, []);

        final progressCalls = <(int, int)>[];

        // Act
        await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page2],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 10,
          onProgress: (checked, total) {
            progressCalls.add((checked, total));
          },
        );

        // Assert
        expect(progressCalls, isNotEmpty);
        expect(progressCalls, contains((1, 10))); // First page
        expect(progressCalls, contains((2, 10))); // Second page
      });

      test('should respect startIndex in progress updates', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setExtractedLinks(page1, []);

        final progressCalls = <(int, int)>[];

        // Act
        await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1],
          originalBaseUrl: baseUrl,
          startIndex: 5, // Starting from index 5
          totalPagesInSitemap: 10,
          onProgress: (checked, total) {
            progressCalls.add((checked, total));
          },
        );

        // Assert
        expect(progressCalls.first, (6, 10)); // startIndex(5) + 1
      });

      test('should stop scanning when shouldCancel returns true', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');
        final page2 = Uri.parse('https://example.com/page2');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setHtmlContent(page2, '<html>page2</html>');
        mockHttpClient.setExtractedLinks(page1, []);
        mockHttpClient.setExtractedLinks(page2, []);

        var callCount = 0;

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page2],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 2,
          shouldCancel: () {
            callCount++;
            return callCount > 1; // Cancel after first page
          },
        );

        // Assert
        expect(result.pagesScanned, 1); // Only first page scanned
      });

      test(
        'should correctly distinguish internal from external links',
        () async {
          // Arrange
          final baseUrl = Uri.parse('https://example.com');
          final page1 = Uri.parse('https://example.com/page1');

          final internalLink1 = Uri.parse('https://example.com/internal1');
          final internalLink2 = Uri.parse('https://example.com/internal2');
          final externalLink1 = Uri.parse('https://external1.com/page');
          final externalLink2 = Uri.parse('https://external2.com/page');

          mockHttpClient.setHtmlContent(page1, '<html>content</html>');
          mockHttpClient.setExtractedLinks(page1, [
            internalLink1,
            internalLink2,
            externalLink1,
            externalLink2,
          ]);

          // Act
          final result = await extractor.scanPagesAndExtractLinks(
            pagesToScan: [page1],
            originalBaseUrl: baseUrl,
            startIndex: 0,
            totalPagesInSitemap: 1,
          );

          // Assert
          expect(result.internalLinks, hasLength(2));
          expect(result.externalLinks, hasLength(2));
          expect(result.totalInternalLinksCount, 2);
          expect(result.totalExternalLinksCount, 2);
        },
      );

      test('should not count duplicate links multiple times', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');
        final page2 = Uri.parse('https://example.com/page2');

        final duplicateLink = Uri.parse('https://example.com/duplicate');

        mockHttpClient.setHtmlContent(page1, '<html>page1</html>');
        mockHttpClient.setHtmlContent(page2, '<html>page2</html>');
        // Both pages contain the same link
        mockHttpClient.setExtractedLinks(page1, [duplicateLink]);
        mockHttpClient.setExtractedLinks(page2, [duplicateLink]);

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1, page2],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 2,
        );

        // Assert
        expect(result.internalLinks, hasLength(1)); // Unique link counted once
        expect(result.totalInternalLinksCount, 1);
      });

      test('should handle empty pages list', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 0,
        );

        // Assert
        expect(result.internalLinks, isEmpty);
        expect(result.externalLinks, isEmpty);
        expect(result.pagesScanned, 0);
        expect(result.totalInternalLinksCount, 0);
        expect(result.totalExternalLinksCount, 0);
      });

      test('should handle pages with no links', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page1 = Uri.parse('https://example.com/page1');

        mockHttpClient.setHtmlContent(page1, '<html>no links</html>');
        mockHttpClient.setExtractedLinks(page1, []); // No links

        // Act
        final result = await extractor.scanPagesAndExtractLinks(
          pagesToScan: [page1],
          originalBaseUrl: baseUrl,
          startIndex: 0,
          totalPagesInSitemap: 1,
        );

        // Assert
        expect(result.internalLinks, isEmpty);
        expect(result.externalLinks, isEmpty);
        expect(result.pagesScanned, 1); // Page was scanned
      });
    });

    group('scanAndExtractLinksForPage', () {
      test('should successfully extract links from a single page', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page = Uri.parse('https://example.com/page1');
        final internalLink = Uri.parse('https://example.com/page2');
        final externalLink = Uri.parse('https://external.com/page');

        mockHttpClient.setHtmlContent(page, '<html>mock content</html>');
        mockHttpClient.setExtractedLinks(page, [internalLink, externalLink]);

        // Act
        final result = await extractor.scanAndExtractLinksForPage(
          page: page,
          originalBaseUrl: baseUrl,
        );

        // Assert
        expect(result.wasSuccessful, true);
        expect(result.internalLinks, contains(internalLink));
        expect(result.externalLinks, contains(externalLink));
        expect(result.internalLinksCount, 1);
        expect(result.externalLinksCount, 1);
        expect(result.linkSourceMap[internalLink.toString()], [
          page.toString(),
        ]);
        expect(result.linkSourceMap[externalLink.toString()], [
          page.toString(),
        ]);
      });

      test('should handle failed page fetch gracefully', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page = Uri.parse('https://example.com/page1');

        mockHttpClient.setHtmlContent(page, null); // Simulate fetch failure

        // Act
        final result = await extractor.scanAndExtractLinksForPage(
          page: page,
          originalBaseUrl: baseUrl,
        );

        // Assert
        expect(result.wasSuccessful, false);
        expect(result.internalLinks, isEmpty);
        expect(result.externalLinks, isEmpty);
        expect(result.internalLinksCount, 0);
        expect(result.externalLinksCount, 0);
        expect(result.linkSourceMap, isEmpty);
      });

      test('should handle cancellation via shouldCancel', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page = Uri.parse('https://example.com/page1');

        // Act
        final result = await extractor.scanAndExtractLinksForPage(
          page: page,
          originalBaseUrl: baseUrl,
          shouldCancel: () => true, // Simulate cancellation
        );

        // Assert
        expect(result.wasSuccessful, false);
        expect(result.internalLinks, isEmpty);
        expect(result.externalLinks, isEmpty);
        expect(result.internalLinksCount, 0);
        expect(result.externalLinksCount, 0);
      });

      test('should count link occurrences correctly', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page = Uri.parse('https://example.com/page1');
        final link1 = Uri.parse('https://example.com/page2');
        final link2 = Uri.parse('https://example.com/page3');

        mockHttpClient.setHtmlContent(page, '<html>mock content</html>');
        mockHttpClient.setExtractedLinks(page, [
          link1,
          link2,
          link1,
        ]); // link1 appears twice

        // Act
        final result = await extractor.scanAndExtractLinksForPage(
          page: page,
          originalBaseUrl: baseUrl,
        );

        // Assert
        expect(result.wasSuccessful, true);
        expect(result.internalLinks.length, 2); // Unique links
        expect(result.internalLinksCount, 2); // Unique count (set behavior)
      });

      test('should track link source map correctly', () async {
        // Arrange
        final baseUrl = Uri.parse('https://example.com');
        final page = Uri.parse('https://example.com/page1');
        final internalLink = Uri.parse('https://example.com/page2');
        final externalLink = Uri.parse('https://external.com/page');

        mockHttpClient.setHtmlContent(page, '<html>mock content</html>');
        mockHttpClient.setExtractedLinks(page, [internalLink, externalLink]);

        // Act
        final result = await extractor.scanAndExtractLinksForPage(
          page: page,
          originalBaseUrl: baseUrl,
        );

        // Assert
        expect(result.linkSourceMap.containsKey(internalLink.toString()), true);
        expect(result.linkSourceMap.containsKey(externalLink.toString()), true);
        expect(result.linkSourceMap[internalLink.toString()], [
          page.toString(),
        ]);
        expect(result.linkSourceMap[externalLink.toString()], [
          page.toString(),
        ]);
      });
    });
  });
}
