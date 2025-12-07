import '../../models/broken_link.dart';
import 'http_client.dart';

/// Validator for checking links and identifying broken ones
class LinkValidator {
  final LinkCheckerHttpClient _httpClient;
  final String userId;
  final String siteUrl;

  LinkValidator({
    required LinkCheckerHttpClient httpClient,
    required this.userId,
    required this.siteUrl,
  }) : _httpClient = httpClient;

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
  /// Uses concurrent checking with backpressure to avoid overwhelming the server.
  /// The first link is checked immediately, subsequent links have minimal delay.
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

    for (final link in links) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final linkUrl = link.toString();

      // Add minimal delay (50ms) between link checks to throttle requests
      // This is much less than the previous 100ms and allows faster processing
      if (checked > 0) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final isBroken = await _httpClient.checkLink(link);

      if (isBroken != null) {
        brokenLinks.add(
          _createBrokenLink(
            siteId: siteId,
            linkUrl: linkUrl,
            linkSourceMap: linkSourceMap,
            statusCode: isBroken.statusCode,
            error: isBroken.error,
            linkType: linkType,
          ),
        );
      }

      checked++;
      onProgress?.call(checked);
    }

    return brokenLinks;
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
