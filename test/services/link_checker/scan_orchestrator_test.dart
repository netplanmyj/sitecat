import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/services/link_checker/http_client.dart';
import 'package:sitecat/services/link_checker/scan_orchestrator.dart';
import 'package:sitecat/services/link_checker/sitemap_parser.dart';

class MockLinkCheckerHttpClient implements LinkCheckerHttpClient {
  final Map<String, ({int statusCode, String? contentType})> _headResponses =
      {};
  Exception? _headException;

  void setHeadResponse(String url, int statusCode) {
    _headResponses[url] = (statusCode: statusCode, contentType: 'text/xml');
  }

  void setHeadException(Exception exception) {
    _headException = exception;
  }

  @override
  Future<({int statusCode, String? contentType})> checkUrlHead(
    String url,
  ) async {
    if (_headException != null) {
      throw _headException!;
    }
    await Future.delayed(const Duration(milliseconds: 1));
    return _headResponses[url] ?? (statusCode: 200, contentType: 'text/xml');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSitemapParser implements SitemapParser {
  final Map<String, List<Uri>> _sitemapUrls = {};
  Exception? _fetchException;

  void setSitemapUrls(String url, List<Uri> urls) {
    _sitemapUrls[url] = urls;
  }

  void setFetchException(Exception exception) {
    _fetchException = exception;
  }

  @override
  Future<List<Uri>> fetchSitemapUrls(
    String sitemapUrl,
    Future<({int statusCode, String? contentType})> Function(String)
    checkUrlHead,
  ) async {
    if (_fetchException != null) {
      throw _fetchException!;
    }
    await Future.delayed(const Duration(milliseconds: 1));
    return _sitemapUrls[sitemapUrl] ?? [];
  }

  @override
  Uri normalizeSitemapUrl(Uri url) => url;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ScanOrchestrator', () {
    late MockLinkCheckerHttpClient httpClient;
    late MockSitemapParser sitemapParser;
    late ScanOrchestrator orchestrator;
    final baseUrl = Uri.parse('https://example.com');
    final originalBaseUrl = Uri.parse('https://example.com');

    late Site testSite;

    setUp(() {
      httpClient = MockLinkCheckerHttpClient();
      sitemapParser = MockSitemapParser();
      orchestrator = ScanOrchestrator(
        httpClient: httpClient,
        sitemapParser: sitemapParser,
        pageLimit: 100,
      );
      testSite = Site(
        id: 'site-1',
        userId: 'user-1',
        url: baseUrl.toString(),
        name: 'Example',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    group('loadSitemapUrls', () {
      test('Case 1: sitemapUrl null -> originalBaseUrl only', () async {
        final result = await orchestrator.loadSitemapUrls(
          site: testSite,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [originalBaseUrl]);
        expect(result.totalPages, 1);
        expect(result.statusCode, isNull);
      });

      test('Case 2: HEAD 200 + sitemap has URLs', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final url1 = Uri.parse('https://example.com/page1');
        final url2 = Uri.parse('https://example.com/page2');

        final site = testSite.copyWith(sitemapUrl: '/sitemap.xml');
        httpClient.setHeadResponse(sitemapUrl, 200);
        sitemapParser.setSitemapUrls(sitemapUrl, [url1, url2]);

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, hasLength(2));
        expect(result.totalPages, 2);
        expect(result.statusCode, 200);
      });

      test('Case 3: HEAD 404 -> fallback to originalBaseUrl', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final site = testSite.copyWith(sitemapUrl: '/sitemap.xml');
        httpClient.setHeadResponse(sitemapUrl, 404);

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [originalBaseUrl]);
        expect(result.statusCode, 404);
      });

      test('Case 4: HEAD exception -> statusCode 0 + fallback', () async {
        final site = testSite.copyWith(sitemapUrl: '/sitemap.xml');
        httpClient.setHeadException(Exception('Connection timeout'));

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [originalBaseUrl]);
        expect(result.statusCode, 0);
      });

      test('Case 5: fetchSitemapUrls returns empty -> fallback', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final site = testSite.copyWith(sitemapUrl: '/sitemap.xml');
        httpClient.setHeadResponse(sitemapUrl, 200);
        sitemapParser.setSitemapUrls(sitemapUrl, []);

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [originalBaseUrl]);
        expect(result.totalPages, 1);
      });

      test('Case 6: excludedPaths removes all -> fallback', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final url1 = Uri.parse('https://example.com/admin');
        final site = testSite.copyWith(
          sitemapUrl: '/sitemap.xml',
          excludedPaths: const ['/admin'],
        );
        httpClient.setHeadResponse(sitemapUrl, 200);
        sitemapParser.setSitemapUrls(sitemapUrl, [url1]);

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [originalBaseUrl]);
        expect(result.totalPages, 1);
      });

      test('Case 7: excludedPaths removes some but keeps others', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final url1 = Uri.parse('https://example.com/admin/page');
        final url2 = Uri.parse('https://example.com/keep');
        final site = testSite.copyWith(
          sitemapUrl: '/sitemap.xml',
          excludedPaths: const ['/admin'],
        );
        httpClient.setHeadResponse(sitemapUrl, 200);
        sitemapParser.setSitemapUrls(sitemapUrl, [url1, url2]);

        final result = await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
        );

        expect(result.urls, [url2]);
        expect(result.totalPages, 1);
      });

      test('Case 8: onSitemapStatusUpdate called for 200, 404, 0', () async {
        final sitemapUrl = 'https://example.com/sitemap.xml';
        final site = testSite.copyWith(sitemapUrl: '/sitemap.xml');
        final statuses = <int?>[];

        // 200
        httpClient.setHeadResponse(sitemapUrl, 200);
        sitemapParser.setSitemapUrls(sitemapUrl, [
          Uri.parse('https://example.com/p1'),
        ]);
        await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
          onSitemapStatusUpdate: (s) => statuses.add(s),
        );

        // 404
        httpClient = MockLinkCheckerHttpClient();
        sitemapParser = MockSitemapParser();
        orchestrator = ScanOrchestrator(
          httpClient: httpClient,
          sitemapParser: sitemapParser,
          pageLimit: 100,
        );
        httpClient.setHeadResponse(sitemapUrl, 404);
        await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
          onSitemapStatusUpdate: (s) => statuses.add(s),
        );

        // 0 (exception)
        httpClient = MockLinkCheckerHttpClient();
        sitemapParser = MockSitemapParser();
        orchestrator = ScanOrchestrator(
          httpClient: httpClient,
          sitemapParser: sitemapParser,
          pageLimit: 100,
        );
        httpClient.setHeadException(Exception('Timeout'));
        await orchestrator.loadSitemapUrls(
          site: site,
          baseUrl: baseUrl,
          originalBaseUrl: originalBaseUrl,
          onSitemapStatusUpdate: (s) => statuses.add(s),
        );

        expect(statuses, [200, 404, 0]);
      });
    });
  });
}
