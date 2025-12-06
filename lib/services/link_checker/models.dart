import '../../models/broken_link.dart';

/// Result of sitemap loading operation
class SitemapLoadResult {
  final List<Uri> urls;
  final int totalPages;
  final int? statusCode;

  const SitemapLoadResult({
    required this.urls,
    required this.totalPages,
    required this.statusCode,
  });
}

/// Result of previous scan data loading
class PreviousScanData {
  final LinkCheckResult? result;
  final List<BrokenLink> brokenLinks;

  const PreviousScanData({required this.result, required this.brokenLinks});
}

/// Calculated scan range for batch processing
class ScanRange {
  final List<Uri> pagesToScan;
  final int endIndex;
  final bool scanCompleted;

  const ScanRange({
    required this.pagesToScan,
    required this.endIndex,
    required this.scanCompleted,
  });
}

/// Result of link extraction from pages
class LinkExtractionResult {
  final Set<Uri> internalLinks;
  final Set<Uri> externalLinks;
  final Map<String, List<String>> linkSourceMap;
  final int totalInternalLinksCount;
  final int totalExternalLinksCount;
  final int pagesScanned;

  const LinkExtractionResult({
    required this.internalLinks,
    required this.externalLinks,
    required this.linkSourceMap,
    required this.totalInternalLinksCount,
    required this.totalExternalLinksCount,
    required this.pagesScanned,
  });
}
