import 'dart:math';

import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../utils/url_helper.dart';
import 'models.dart';
import 'http_client.dart';
import 'sitemap_parser.dart';

/// Orchestrates the scanning process: sitemap loading, previous data, and range calculation
class ScanOrchestrator {
  final LinkCheckerHttpClient _httpClient;
  final SitemapParser _sitemapParser;
  final int pageLimit;

  ScanOrchestrator({
    required LinkCheckerHttpClient httpClient,
    required SitemapParser sitemapParser,
    required this.pageLimit,
  }) : _httpClient = httpClient,
       _sitemapParser = sitemapParser;

  /// Load sitemap URLs and check accessibility
  Future<SitemapLoadResult> loadSitemapUrls({
    required Site site,
    required Uri baseUrl,
    required Uri originalBaseUrl,
    void Function(int? statusCode)? onSitemapStatusUpdate,
  }) async {
    List<Uri> allInternalPages = [];
    int? sitemapStatusCode;

    if (site.sitemapUrl != null && site.sitemapUrl!.isNotEmpty) {
      try {
        final fullSitemapUrl = _buildFullUrl(baseUrl, site.sitemapUrl!);

        try {
          final convertedUrl = UrlHelper.convertLocalhostForPlatform(
            fullSitemapUrl,
          );
          final headCheck = await _httpClient.checkUrlHead(convertedUrl);
          sitemapStatusCode = headCheck.statusCode;

          onSitemapStatusUpdate?.call(sitemapStatusCode);

          if (sitemapStatusCode == 200) {
            allInternalPages = await _sitemapParser.fetchSitemapUrls(
              fullSitemapUrl,
              _httpClient.checkUrlHead,
            );
          } else {
            allInternalPages = [originalBaseUrl];
          }
        } catch (e) {
          sitemapStatusCode = 0;
          onSitemapStatusUpdate?.call(sitemapStatusCode);
          allInternalPages = [originalBaseUrl];
        }

        if (site.excludedPaths.isNotEmpty) {
          allInternalPages = _filterExcludedPaths(
            allInternalPages,
            site.excludedPaths,
          );
        }

        if (allInternalPages.isEmpty) {
          allInternalPages = [originalBaseUrl];
        }
      } catch (e) {
        allInternalPages = [originalBaseUrl];
      }
    } else {
      allInternalPages = [originalBaseUrl];
    }

    return SitemapLoadResult(
      urls: allInternalPages,
      totalPages: allInternalPages.length,
      statusCode: sitemapStatusCode,
    );
  }

  /// Load previous scan data if continuing from last scan
  Future<PreviousScanData> loadPreviousScanData({
    required bool continueFromLastScan,
    required int startIndex,
    required Future<LinkCheckResult?> Function(String siteId) getLatestResult,
    required Future<List<BrokenLink>> Function(String resultId) getBrokenLinks,
    required String siteId,
  }) async {
    if (!continueFromLastScan || startIndex == 0) {
      return const PreviousScanData(result: null, brokenLinks: <BrokenLink>[]);
    }

    final previousResult = await getLatestResult(siteId);
    if (previousResult == null || previousResult.id == null) {
      return const PreviousScanData(result: null, brokenLinks: <BrokenLink>[]);
    }

    final previousBrokenLinks = await getBrokenLinks(previousResult.id!);
    return PreviousScanData(
      result: previousResult,
      brokenLinks: previousBrokenLinks,
    );
  }

  /// Calculate the range of pages to scan in this batch
  ScanRange calculateScanRange({
    required List<Uri> allPages,
    required int startIndex,
  }) {
    const batchPageCap = 100;

    // Next boundary is the next multiple of 100 pages (1-100, 101-200, ...)
    final nextBoundary = ((startIndex ~/ batchPageCap) + 1) * batchPageCap;
    final batchEnd = min(nextBoundary, min(pageLimit, allPages.length));

    final actualPagesToScan = max(0, batchEnd - startIndex);

    final endIndex = min(allPages.length, startIndex + actualPagesToScan);
    final pagesToScan = allPages.sublist(startIndex, endIndex);
    final scanCompleted = endIndex >= allPages.length || endIndex >= pageLimit;

    return ScanRange(
      pagesToScan: pagesToScan,
      endIndex: endIndex,
      scanCompleted: scanCompleted,
    );
  }

  /// Build full URL from base URL and path
  String _buildFullUrl(Uri baseUrl, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final baseStr = baseUrl.toString().replaceAll(RegExp(r'/$'), '');
    final pathStr = path.startsWith('/') ? path : '/$path';
    return '$baseStr$pathStr';
  }

  /// Filter out URLs that match excluded paths
  /// Supports both prefix matching and wildcard patterns (e.g., '*/admin/')
  List<Uri> _filterExcludedPaths(List<Uri> urls, List<String> excludedPaths) {
    final normalizedExcludedPaths = excludedPaths.map((path) {
      return path.startsWith('/') ? path : '/$path';
    }).toList();

    return urls.where((url) {
      final urlPath = url.path;

      // Check for prefix matches
      final prefixExcluded = normalizedExcludedPaths.any(
        (excluded) => urlPath.startsWith(excluded),
      );
      if (prefixExcluded) return false;

      // Check for wildcard segment matches (e.g., '*/admin/')
      final wildcardExcluded = excludedPaths.any((excludedPath) {
        if (excludedPath.startsWith('*/')) {
          final pattern = excludedPath.substring(2).replaceAll('/', '');
          final pathSegments = urlPath.split('/');
          return pathSegments.any((segment) => segment == pattern);
        }
        return false;
      });

      return !wildcardExcluded;
    }).toList();
  }
}
