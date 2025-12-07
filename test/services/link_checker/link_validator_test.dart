import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/link_checker/link_validator.dart';
import 'package:sitecat/services/link_checker/http_client.dart';
import 'package:sitecat/models/broken_link.dart';

/// Mock implementation of LinkCheckerHttpClient for testing
class MockLinkCheckerHttpClient implements LinkCheckerHttpClient {
  final Map<Uri, ({int statusCode, String? error})?> _responses = {};

  void setResponse(Uri uri, {required int statusCode, String? error}) {
    _responses[uri] = (statusCode: statusCode, error: error);
  }

  void setSuccess(Uri uri) {
    _responses[uri] = null; // null means link is working
  }

  @override
  Future<({int statusCode, String? error})?> checkLink(Uri url) async {
    await Future.delayed(
      const Duration(milliseconds: 1),
    ); // Simulate network delay
    return _responses[url];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LinkValidator', () {
    late MockLinkCheckerHttpClient mockHttpClient;
    late LinkValidator validator;
    const testUserId = 'test-user-id';
    const testSiteUrl = 'https://example.com';
    const testSiteId = 'test-site-id';

    setUp(() {
      mockHttpClient = MockLinkCheckerHttpClient();
      validator = LinkValidator(
        httpClient: mockHttpClient,
        userId: testUserId,
        siteUrl: testSiteUrl,
      );
    });

    group('checkAllLinks', () {
      test('should return empty list when no links provided', () async {
        // Arrange
        final internalLinks = <Uri>{};
        final externalLinks = <Uri>{};

        // Act
        final result = await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: internalLinks,
          externalLinks: externalLinks,
          linkSourceMap: {},
          checkExternalLinks: true,
          startIndex: 0,
          pagesScanned: 0,
          totalPagesInSitemap: 0,
        );

        // Assert
        expect(result, isEmpty);
      });

      test(
        'should check internal links only when checkExternalLinks is false',
        () async {
          // Arrange
          final internalUrl1 = Uri.parse('https://example.com/page1');
          final internalUrl2 = Uri.parse('https://example.com/page2');
          final externalUrl = Uri.parse('https://external.com/page');

          final internalLinks = {internalUrl1, internalUrl2};
          final externalLinks = {externalUrl};

          // All links return success (null)
          mockHttpClient.setSuccess(internalUrl1);
          mockHttpClient.setSuccess(internalUrl2);

          // Act
          final result = await validator.checkAllLinks(
            siteId: testSiteId,
            internalLinks: internalLinks,
            externalLinks: externalLinks,
            linkSourceMap: {},
            checkExternalLinks: false,
            startIndex: 0,
            pagesScanned: 2,
            totalPagesInSitemap: 10,
          );

          // Assert
          expect(result, isEmpty);
        },
      );

      test('should detect broken internal links', () async {
        // Arrange
        final brokenUrl = Uri.parse('https://example.com/broken');
        final workingUrl = Uri.parse('https://example.com/working');

        final internalLinks = {brokenUrl, workingUrl};

        mockHttpClient.setResponse(brokenUrl, statusCode: 404);
        mockHttpClient.setSuccess(workingUrl);

        // Act
        final result = await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: internalLinks,
          externalLinks: {},
          linkSourceMap: {
            brokenUrl.toString(): ['https://example.com/source'],
          },
          checkExternalLinks: false,
          startIndex: 0,
          pagesScanned: 2,
          totalPagesInSitemap: 10,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].url, brokenUrl.toString());
        expect(result[0].statusCode, 404);
        expect(result[0].linkType, LinkType.internal);
      });

      test(
        'should detect broken external links when checkExternalLinks is true',
        () async {
          // Arrange
          final brokenUrl = Uri.parse('https://external.com/broken');
          final workingUrl = Uri.parse('https://external.com/working');

          final externalLinks = {brokenUrl, workingUrl};

          mockHttpClient.setResponse(brokenUrl, statusCode: 404);
          mockHttpClient.setSuccess(workingUrl);

          // Act
          final result = await validator.checkAllLinks(
            siteId: testSiteId,
            internalLinks: {},
            externalLinks: externalLinks,
            linkSourceMap: {
              brokenUrl.toString(): ['https://example.com/source'],
            },
            checkExternalLinks: true,
            startIndex: 0,
            pagesScanned: 0,
            totalPagesInSitemap: 10,
          );

          // Assert
          expect(result, hasLength(1));
          expect(result[0].url, brokenUrl.toString());
          expect(result[0].statusCode, 404);
          expect(result[0].linkType, LinkType.external);
        },
      );

      test('should handle network errors', () async {
        // Arrange
        final timeoutUrl = Uri.parse('https://example.com/timeout');

        mockHttpClient.setResponse(
          timeoutUrl,
          statusCode: 0,
          error: 'Connection timeout',
        );

        // Act
        final result = await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: {timeoutUrl},
          externalLinks: {},
          linkSourceMap: {},
          checkExternalLinks: false,
          startIndex: 0,
          pagesScanned: 1,
          totalPagesInSitemap: 10,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0].url, timeoutUrl.toString());
        expect(result[0].statusCode, 0);
        expect(result[0].error, 'Connection timeout');
      });

      test(
        'should check both internal and external links when checkExternalLinks is true',
        () async {
          // Arrange
          final internalUrl = Uri.parse('https://example.com/page');
          final externalUrl = Uri.parse('https://external.com/page');

          mockHttpClient.setSuccess(internalUrl);
          mockHttpClient.setSuccess(externalUrl);

          // Act
          final result = await validator.checkAllLinks(
            siteId: testSiteId,
            internalLinks: {internalUrl},
            externalLinks: {externalUrl},
            linkSourceMap: {},
            checkExternalLinks: true,
            startIndex: 0,
            pagesScanned: 1,
            totalPagesInSitemap: 10,
          );

          // Assert
          expect(result, isEmpty); // No broken links
        },
      );

      test('should handle multiple broken links of different types', () async {
        // Arrange
        final internal1 = Uri.parse('https://example.com/broken1');
        final internal2 = Uri.parse('https://example.com/broken2');
        final external1 = Uri.parse('https://external.com/broken');

        mockHttpClient.setResponse(internal1, statusCode: 404);
        mockHttpClient.setResponse(internal2, statusCode: 500);
        mockHttpClient.setResponse(external1, statusCode: 403);

        // Act
        final result = await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: {internal1, internal2},
          externalLinks: {external1},
          linkSourceMap: {},
          checkExternalLinks: true,
          startIndex: 0,
          pagesScanned: 2,
          totalPagesInSitemap: 10,
        );

        // Assert
        expect(result, hasLength(3));
        expect(
          result.where((l) => l.linkType == LinkType.internal),
          hasLength(2),
        );
        expect(
          result.where((l) => l.linkType == LinkType.external),
          hasLength(1),
        );
        expect(result.map((l) => l.statusCode), containsAll([404, 500, 403]));
      });
    });

    group('BrokenLink creation', () {
      test('should create BrokenLink with correct properties', () async {
        // Arrange
        final url = Uri.parse('https://example.com/broken');
        mockHttpClient.setResponse(url, statusCode: 404);

        // Act
        final result = await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: {url},
          externalLinks: {},
          linkSourceMap: {
            url.toString(): ['https://example.com/source-page'],
          },
          checkExternalLinks: false,
          startIndex: 0,
          pagesScanned: 1,
          totalPagesInSitemap: 10,
        );

        // Assert
        expect(result, hasLength(1));
        final brokenLink = result[0];
        expect(brokenLink.url, url.toString());
        expect(brokenLink.statusCode, 404);
        expect(brokenLink.linkType, LinkType.internal);
        expect(brokenLink.userId, testUserId);
        expect(brokenLink.siteId, testSiteId);
        expect(brokenLink.foundOn, 'https://example.com/source-page');
        expect(brokenLink.timestamp, isNotNull);
      });

      test(
        'should use siteUrl as foundOn when linkSourceMap is empty',
        () async {
          // Arrange
          final url = Uri.parse('https://example.com/broken');
          mockHttpClient.setResponse(url, statusCode: 404);

          // Act
          final result = await validator.checkAllLinks(
            siteId: testSiteId,
            internalLinks: {url},
            externalLinks: {},
            linkSourceMap: {}, // Empty source map
            checkExternalLinks: false,
            startIndex: 0,
            pagesScanned: 1,
            totalPagesInSitemap: 10,
          );

          // Assert
          expect(result, hasLength(1));
          expect(result[0].foundOn, testSiteUrl);
        },
      );
    });

    group('progress callbacks', () {
      test('should call onProgress callback during link checking', () async {
        // Arrange
        final url1 = Uri.parse('https://example.com/page1');
        final url2 = Uri.parse('https://example.com/page2');

        mockHttpClient.setSuccess(url1);
        mockHttpClient.setSuccess(url2);

        final progressCalls = <int>[];

        // Act
        await validator.checkAllLinks(
          siteId: testSiteId,
          internalLinks: {url1, url2},
          externalLinks: {},
          linkSourceMap: {},
          checkExternalLinks: false,
          startIndex: 0,
          pagesScanned: 2,
          totalPagesInSitemap: 10,
          onExternalLinksProgress: (checked, total) {
            progressCalls.add(checked);
          },
        );

        // Assert
        expect(progressCalls, isNotEmpty);
        expect(progressCalls.first, 0); // Initial state
        expect(progressCalls.last, 2); // Completed
      });
    });

    group('checkLinksFromPage', () {
      test(
        'should validate internal and external links from a single page',
        () async {
          // Arrange
          final internalUrl = Uri.parse('https://example.com/page1');
          final externalUrl = Uri.parse('https://external.com/page');
          final internalLinks = {internalUrl};
          final externalLinks = {externalUrl};
          final linkSourceMap = {
            internalUrl.toString(): ['https://example.com/source'],
            externalUrl.toString(): ['https://example.com/source'],
          };

          mockHttpClient.setSuccess(internalUrl);
          mockHttpClient.setSuccess(externalUrl);

          // Act
          final result = await validator.checkLinksFromPage(
            siteId: testSiteId,
            internalLinks: internalLinks,
            externalLinks: externalLinks,
            linkSourceMap: linkSourceMap,
            checkExternalLinks: true,
          );

          // Assert
          expect(result, isEmpty); // No broken links
        },
      );

      test('should detect broken internal links', () async {
        // Arrange
        final internalUrl = Uri.parse('https://example.com/page1');
        final internalLinks = {internalUrl};
        final externalLinks = <Uri>{};
        final linkSourceMap = {
          internalUrl.toString(): ['https://example.com/source'],
        };

        mockHttpClient.setResponse(
          internalUrl,
          statusCode: 404,
          error: 'Not Found',
        );

        // Act
        final result = await validator.checkLinksFromPage(
          siteId: testSiteId,
          internalLinks: internalLinks,
          externalLinks: externalLinks,
          linkSourceMap: linkSourceMap,
          checkExternalLinks: false,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.url, internalUrl.toString());
        expect(result.first.linkType, LinkType.internal);
      });

      test(
        'should skip external links when checkExternalLinks is false',
        () async {
          // Arrange
          final internalUrl = Uri.parse('https://example.com/page1');
          final externalUrl = Uri.parse('https://external.com/page');
          final internalLinks = {internalUrl};
          final externalLinks = {externalUrl};
          final linkSourceMap = {
            internalUrl.toString(): ['https://example.com/source'],
            externalUrl.toString(): ['https://example.com/source'],
          };

          mockHttpClient.setSuccess(internalUrl);
          mockHttpClient.setResponse(
            externalUrl,
            statusCode: 404,
            error: 'Not Found',
          ); // This should not be detected

          // Act
          final result = await validator.checkLinksFromPage(
            siteId: testSiteId,
            internalLinks: internalLinks,
            externalLinks: externalLinks,
            linkSourceMap: linkSourceMap,
            checkExternalLinks: false,
          );

          // Assert
          expect(result, isEmpty); // External link not checked
        },
      );

      test('should invoke progress callback with correct values', () async {
        // Arrange
        final internalUrl1 = Uri.parse('https://example.com/page1');
        final internalUrl2 = Uri.parse('https://example.com/page2');
        final externalUrl = Uri.parse('https://external.com/page');
        final internalLinks = {internalUrl1, internalUrl2};
        final externalLinks = {externalUrl};
        final linkSourceMap = {
          internalUrl1.toString(): ['https://example.com/source'],
          internalUrl2.toString(): ['https://example.com/source'],
          externalUrl.toString(): ['https://example.com/source'],
        };

        mockHttpClient.setSuccess(internalUrl1);
        mockHttpClient.setSuccess(internalUrl2);
        mockHttpClient.setSuccess(externalUrl);

        final progressCalls = <(int checked, int total)>[];

        // Act
        await validator.checkLinksFromPage(
          siteId: testSiteId,
          internalLinks: internalLinks,
          externalLinks: externalLinks,
          linkSourceMap: linkSourceMap,
          checkExternalLinks: true,
          onExternalLinksProgress: (checked, total) {
            progressCalls.add((checked, total));
          },
        );

        // Assert
        expect(progressCalls.isNotEmpty, true);
        expect(progressCalls.first.$2, 3); // Total = 2 internal + 1 external
        expect(progressCalls.last.$1, 3); // All checked
      });

      test('should handle cancellation via shouldCancel', () async {
        // Arrange
        final internalUrl = Uri.parse('https://example.com/page1');
        final internalLinks = {internalUrl};
        final externalLinks = <Uri>{};
        final linkSourceMap = {
          internalUrl.toString(): ['https://example.com/source'],
        };

        mockHttpClient.setSuccess(internalUrl);

        // Act
        final result = await validator.checkLinksFromPage(
          siteId: testSiteId,
          internalLinks: internalLinks,
          externalLinks: externalLinks,
          linkSourceMap: linkSourceMap,
          checkExternalLinks: false,
          shouldCancel: () => true, // Simulate cancellation
        );

        // Assert - With cancellation, result may be empty or partial
        expect(result, isEmpty);
      });
    });
  });
}
