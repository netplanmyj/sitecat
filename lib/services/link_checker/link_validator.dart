import '../../models/broken_link.dart';
import 'http_client.dart';

/// Validator for checking links and identifying broken ones
class LinkValidator {
  final LinkCheckerHttpClient _httpClient;
  final String userId;
  final String siteUrl;

  // Cache for link check results (URL -> {statusCode, error})
  final Map<String, ({int statusCode, String? error})?> _linkCheckCache = {};

  LinkValidator({
    required LinkCheckerHttpClient httpClient,
    required this.userId,
    required this.siteUrl,
  }) : _httpClient = httpClient;

  /// Clear the link check cache
  void clearCache() {
    _linkCheckCache.clear();
  }

  /// Check all links (internal and external) for broken pages
  Future<List<BrokenLink>> checkAllLinks({
    required String siteId,
    required Set<Uri> internalLinks,
    required Set<Uri> externalLinks,
    required Map<String, List<String>> linkSourceMap,
    required bool checkExternalLinks,
    required int startIndex,
    required int pagesScanned,
    required int totalPagesInSitemap,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    bool Function()? shouldCancel,
  }) async {
    final brokenLinks = <BrokenLink>[];
    final internalLinksList = internalLinks.toList();
    final totalInternalLinks = internalLinksList.length;

    final externalLinksCount = checkExternalLinks ? externalLinks.length : 0;
    final totalAllLinks = totalInternalLinks + externalLinksCount;

    // Report initial state
    if (totalAllLinks > 0) {
      onExternalLinksProgress?.call(0, totalAllLinks);
    }

    // Check internal links
    final internalBrokenLinks = await _checkLinks(
      siteId: siteId,
      links: internalLinksList,
      linkSourceMap: linkSourceMap,
      linkType: LinkType.internal,
      onProgress: (checked) {
        if (totalAllLinks > 0) {
          onExternalLinksProgress?.call(checked, totalAllLinks);
        }
      },
      shouldCancel: shouldCancel,
    );
    brokenLinks.addAll(internalBrokenLinks);

    // Check external links (if requested)
    if (checkExternalLinks) {
      final cumulativePagesScanned = startIndex + pagesScanned;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      final externalBrokenLinks = await _checkLinks(
        siteId: siteId,
        links: externalLinks.toList(),
        linkSourceMap: linkSourceMap,
        linkType: LinkType.external,
        onProgress: (checkedExternal) {
          final totalChecked = internalLinksList.length + checkedExternal;
          onExternalLinksProgress?.call(totalChecked, totalAllLinks);
        },
        shouldCancel: shouldCancel,
      );
      brokenLinks.addAll(externalBrokenLinks);
    }

    return brokenLinks;
  }

  /// Check links from a single page for broken ones
  /// This method is used for per-page processing in the new page-wise validation flow.
  ///
  /// Returns a list of broken links found in the provided links.
  Future<List<BrokenLink>> checkLinksFromPage({
    required String siteId,
    required Set<Uri> internalLinks,
    required Set<Uri> externalLinks,
    required Map<String, List<String>> linkSourceMap,
    required bool checkExternalLinks,
    void Function(int checked, int total)? onExternalLinksProgress,
    bool Function()? shouldCancel,
  }) async {
    final brokenLinks = <BrokenLink>[];
    final internalLinksList = internalLinks.toList();
    final totalInternalLinks = internalLinksList.length;

    final externalLinksCount = checkExternalLinks ? externalLinks.length : 0;
    final totalAllLinks = totalInternalLinks + externalLinksCount;

    // Report initial state
    if (totalAllLinks > 0) {
      onExternalLinksProgress?.call(0, totalAllLinks);
    }

    // Check internal links from this page
    final internalBrokenLinks = await _checkLinks(
      siteId: siteId,
      links: internalLinksList,
      linkSourceMap: linkSourceMap,
      linkType: LinkType.internal,
      onProgress: (checked) {
        if (totalAllLinks > 0) {
          onExternalLinksProgress?.call(checked, totalAllLinks);
        }
      },
      shouldCancel: shouldCancel,
    );
    brokenLinks.addAll(internalBrokenLinks);

    // Check external links from this page (if requested)
    if (checkExternalLinks) {
      final externalBrokenLinks = await _checkLinks(
        siteId: siteId,
        links: externalLinks.toList(),
        linkSourceMap: linkSourceMap,
        linkType: LinkType.external,
        onProgress: (checkedExternal) {
          final totalChecked = internalLinksList.length + checkedExternal;
          onExternalLinksProgress?.call(totalChecked, totalAllLinks);
        },
        shouldCancel: shouldCancel,
      );
      brokenLinks.addAll(externalBrokenLinks);
    }

    return brokenLinks;
  }

  /// Check a list of links for broken ones
  /// Uses concurrent checking with limited parallelism to optimize speed while avoiding server overload.
  /// Implements caching to avoid checking the same URL multiple times across pages.
  Future<List<BrokenLink>> _checkLinks({
    required String siteId,
    required List<Uri> links,
    required Map<String, List<String>> linkSourceMap,
    required LinkType linkType,
    void Function(int checked)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final brokenLinks = <BrokenLink>[];
    int checked = 0;

    // Process links in parallel batches of 5 for better performance
    const batchSize = 5;

    for (var i = 0; i < links.length; i += batchSize) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final batch = links.skip(i).take(batchSize).toList();
      final futures =
          <Future<({Uri link, ({int statusCode, String? error})? result})>>[];

      for (final link in batch) {
        final linkUrl = link.toString();

        // Check cache first
        if (_linkCheckCache.containsKey(linkUrl)) {
          // Use cached result (may be null for successful links)
          futures.add(
            Future.value((link: link, result: _linkCheckCache[linkUrl])),
          );
        } else {
          // Queue actual HTTP check
          futures.add(_checkSingleLink(link));
        }
      }

      // Wait for all checks in batch to complete
      final results = await Future.wait(futures);

      // Process results
      for (final result in results) {
        final linkUrl = result.link.toString();

        // Always cache the result
        _linkCheckCache[linkUrl] = result.result;

        // If link is broken, add to broken links list
        if (result.result != null) {
          brokenLinks.add(
            _createBrokenLink(
              siteId: siteId,
              linkUrl: linkUrl,
              linkSourceMap: linkSourceMap,
              statusCode: result.result!.statusCode,
              error: result.result!.error,
              linkType: linkType,
            ),
          );
        }

        checked++;
        onProgress?.call(checked);
      }

      // Small delay between batches to avoid overwhelming the server
      if (i + batchSize < links.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return brokenLinks;
  }

  /// Check a single link and return the result
  Future<({Uri link, ({int statusCode, String? error})? result})>
  _checkSingleLink(Uri link) async {
    final isBroken = await _httpClient.checkLink(link);

    ({int statusCode, String? error})? checkResult;
    if (isBroken != null) {
      checkResult = (statusCode: isBroken.statusCode, error: isBroken.error);
    }

    return (link: link, result: checkResult);
  }

  /// Create a BrokenLink object
  BrokenLink _createBrokenLink({
    required String siteId,
    required String linkUrl,
    required Map<String, List<String>> linkSourceMap,
    required int statusCode,
    required String? error,
    required LinkType linkType,
  }) {
    return BrokenLink(
      id: '',
      siteId: siteId,
      userId: userId,
      timestamp: DateTime.now(),
      url: linkUrl,
      foundOn: linkSourceMap[linkUrl]?.first ?? siteUrl,
      statusCode: statusCode,
      error: error,
      linkType: linkType,
    );
  }
}
