import 'models.dart';
import 'http_client.dart';
import 'sitemap_parser.dart';

/// Extracts links from web pages
class LinkExtractor {
  final LinkCheckerHttpClient _httpClient;
  final SitemapParser _sitemapParser;

  LinkExtractor({
    required LinkCheckerHttpClient httpClient,
    required SitemapParser sitemapParser,
  }) : _httpClient = httpClient,
       _sitemapParser = sitemapParser;

  /// Scan pages and extract all links (internal and external)
  Future<LinkExtractionResult> scanPagesAndExtractLinks({
    required List<Uri> pagesToScan,
    required Uri originalBaseUrl,
    required int startIndex,
    required int totalPagesInSitemap,
    void Function(int checked, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final internalLinks = <Uri>{};
    final externalLinks = <Uri>{};
    final linkSourceMap = <String, List<String>>{};
    final visitedPages = <String>{};

    int totalInternalLinksCount = 0;
    int totalExternalLinksCount = 0;
    int pagesScanned = 0;

    for (final page in pagesToScan) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final pageUrl = page.toString();

      if (visitedPages.contains(pageUrl)) continue;
      visitedPages.add(pageUrl);

      pagesScanned++;
      final cumulativePagesScanned = startIndex + pagesScanned;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      if (pagesScanned > 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final htmlContent = await _httpClient.fetchHtmlContent(pageUrl);
      if (htmlContent == null) continue;

      final links = _httpClient.extractLinks(htmlContent, page);

      for (final link in links) {
        final normalizedLink = _sitemapParser.normalizeSitemapUrl(link);
        final linkUrl = normalizedLink.toString();

        if (!linkSourceMap.containsKey(linkUrl)) {
          linkSourceMap[linkUrl] = [pageUrl];
        } else if (!(linkSourceMap[linkUrl]?.contains(pageUrl) ?? false)) {
          linkSourceMap[linkUrl]!.add(pageUrl);
        }

        if (_isSameDomain(normalizedLink, originalBaseUrl)) {
          if (internalLinks.add(normalizedLink)) {
            totalInternalLinksCount++;
          }
        } else {
          if (externalLinks.add(normalizedLink)) {
            totalExternalLinksCount++;
          }
        }
      }
    }

    return LinkExtractionResult(
      internalLinks: internalLinks,
      externalLinks: externalLinks,
      linkSourceMap: linkSourceMap,
      totalInternalLinksCount: totalInternalLinksCount,
      totalExternalLinksCount: totalExternalLinksCount,
      pagesScanned: pagesScanned,
    );
  }

  /// Scan and extract links from a single page
  /// This method is used for per-page processing in the new page-wise validation flow.
  ///
  /// Returns a [SinglePageExtractionResult] containing:
  /// - internalLinks: Links from the same domain
  /// - externalLinks: Links from other domains
  /// - linkSourceMap: Mapping of links to the source page
  /// - wasSuccessful: true if page was successfully fetched and processed
  ///
  /// Note: The delay between page fetches is applied in the calling code
  /// (checkSiteLinks) to allow for better control over rate limiting.
  Future<SinglePageExtractionResult> scanAndExtractLinksForPage({
    required Uri page,
    required Uri originalBaseUrl,
    bool Function()? shouldCancel,
  }) async {
    if (shouldCancel?.call() ?? false) {
      return SinglePageExtractionResult(
        pageUrl: page,
        internalLinks: {},
        externalLinks: {},
        linkSourceMap: {},
        internalLinksCount: 0,
        externalLinksCount: 0,
        wasSuccessful: false,
      );
    }

    final pageUrl = page.toString();
    final internalLinks = <Uri>{};
    final externalLinks = <Uri>{};
    final linkSourceMap = <String, List<String>>{};

    int internalLinksCount = 0;
    int externalLinksCount = 0;

    final htmlContent = await _httpClient.fetchHtmlContent(pageUrl);
    if (htmlContent == null) {
      return SinglePageExtractionResult(
        pageUrl: page,
        internalLinks: internalLinks,
        externalLinks: externalLinks,
        linkSourceMap: linkSourceMap,
        internalLinksCount: internalLinksCount,
        externalLinksCount: externalLinksCount,
        wasSuccessful: false,
      );
    }

    final links = _httpClient.extractLinks(htmlContent, page);

    for (final link in links) {
      final normalizedLink = _sitemapParser.normalizeSitemapUrl(link);
      final linkUrl = normalizedLink.toString();

      // Track which page this link was found on
      if (!linkSourceMap.containsKey(linkUrl)) {
        linkSourceMap[linkUrl] = [pageUrl];
      } else if (!(linkSourceMap[linkUrl]?.contains(pageUrl) ?? false)) {
        linkSourceMap[linkUrl]!.add(pageUrl);
      }

      if (_isSameDomain(normalizedLink, originalBaseUrl)) {
        if (internalLinks.add(normalizedLink)) {
          internalLinksCount++;
        }
      } else {
        if (externalLinks.add(normalizedLink)) {
          externalLinksCount++;
        }
      }
    }

    return SinglePageExtractionResult(
      pageUrl: page,
      internalLinks: internalLinks,
      externalLinks: externalLinks,
      linkSourceMap: linkSourceMap,
      internalLinksCount: internalLinksCount,
      externalLinksCount: externalLinksCount,
      wasSuccessful: true,
    );
  }

  /// Check if two URLs are from the same domain
  bool _isSameDomain(Uri url1, Uri url2) {
    final host1 = _normalizeEmulatorHost(url1.host);
    final host2 = _normalizeEmulatorHost(url2.host);
    return host1 == host2;
  }

  /// Normalize Android emulator special addresses
  String _normalizeEmulatorHost(String host) {
    if (host == '10.0.2.2') return 'localhost';
    return host;
  }
}
