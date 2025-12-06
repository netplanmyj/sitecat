import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../utils/url_helper.dart';
import 'link_checker/models.dart';
import 'link_checker/http_client.dart';
import 'link_checker/sitemap_parser.dart';
import 'link_checker/result_repository.dart';
import 'link_checker/link_validator.dart';

/// Service for checking broken links on websites
class LinkCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _httpClient = http.Client();
  final Logger _logger = Logger();

  // Helper classes
  late final LinkCheckerHttpClient _httpHelper;
  late final SitemapParser _sitemapParser;
  LinkCheckResultRepository? _repository;
  String? _repositoryUserId;

  LinkCheckerService() {
    _httpHelper = LinkCheckerHttpClient(_httpClient);
    _sitemapParser = SitemapParser(_httpClient);
  }

  // Get repository instance (lazy initialization)
  LinkCheckResultRepository get _repo {
    final userId = _currentUserId!;
    if (_repository == null || _repositoryUserId != userId) {
      _repositoryUserId = userId;
      _repository = LinkCheckResultRepository(
        firestore: _firestore,
        logger: _logger,
        userId: userId,
        historyLimit: _historyLimit,
      );
    }
    return _repository!;
  }

  // History limit for cleanup (can be set based on premium status)
  int _historyLimit = AppConstants.freePlanHistoryLimit;

  // Page limit for scanning (can be set based on premium status)
  int _pageLimit = AppConstants.freePlanPageLimit;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Set history limit based on premium status
  void setHistoryLimit(bool isPremium) {
    _historyLimit = isPremium
        ? AppConstants.premiumHistoryLimit
        : AppConstants.freePlanHistoryLimit;
  }

  /// Set page limit based on premium status
  void setPageLimit(bool isPremium) {
    _pageLimit = isPremium
        ? AppConstants.premiumPlanPageLimit
        : AppConstants.freePlanPageLimit;
  }

  /// Check all links on a site
  ///
  /// This method performs a comprehensive link check in 6 main steps:
  /// 1. Load sitemap URLs and check accessibility
  ///    - 1a: Load sitemap URLs from configured sitemap.xml
  ///    - 1b: Load previous scan data (if continuing)
  ///    - 1c: Calculate scan range for this batch
  /// 2. Scan pages and extract all links (internal & external)
  /// 3. Check internal links for broken pages
  /// 4. Check external links (if requested)
  /// 5. Merge with previous scan results (if continuing)
  /// 6. Create and save the final result to Firestore
  ///
  /// [onSitemapStatusUpdate] is called immediately after checking sitemap accessibility.
  /// The statusCode represents:
  /// - 200: Sitemap is accessible
  /// - 404: Sitemap not found
  /// - 0: Network error occurred
  /// - null: No sitemap configured
  /// This enables real-time UI updates before the full scan completes.
  ///
  /// [shouldCancel] is called periodically to check if scan should be cancelled.
  /// Return true to stop the scan gracefully.
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = true,
    bool continueFromLastScan = false, // Continue from last scanned index
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    void Function(int? statusCode)? onSitemapStatusUpdate,
    bool Function()? shouldCancel,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check links');
    }

    final startTime = DateTime.now();
    final originalBaseUrl = Uri.parse(site.url);
    final baseUrl = Uri.parse(UrlHelper.convertLocalhostForPlatform(site.url));

    // ========================================================================
    // STEP 1: Load sitemap URLs and check accessibility
    // ========================================================================
    final sitemapData = await _loadSitemapUrls(
      site,
      baseUrl,
      originalBaseUrl,
      onSitemapStatusUpdate,
    );
    final allInternalPages = sitemapData.urls;
    final totalPagesInSitemap = sitemapData.totalPages;
    final sitemapStatusCode = sitemapData.statusCode;

    // ========================================================================
    // STEP 1b: Load previous scan data (if continuing from last scan)
    // ========================================================================
    final startIndex = continueFromLastScan ? site.lastScannedPageIndex : 0;
    final previousData = await _loadPreviousScanData(
      site.id,
      continueFromLastScan,
      startIndex,
    );
    final previousResult = previousData.result;
    final previousBrokenLinks = previousData.brokenLinks;

    // ========================================================================
    // STEP 1c: Calculate scan range for this batch
    // ========================================================================
    final scanRange = _calculateScanRange(allInternalPages, startIndex);
    final pagesToScan = scanRange.pagesToScan;
    final endIndex = scanRange.endIndex;
    final scanCompleted = scanRange.scanCompleted;

    // ========================================================================
    // STEP 2: Scan pages and extract all links
    // ========================================================================
    final linkData = await _scanPagesAndExtractLinks(
      pagesToScan,
      originalBaseUrl,
      startIndex,
      totalPagesInSitemap,
      onProgress,
      shouldCancel,
    );
    final internalLinks = linkData.internalLinks;
    final externalLinks = linkData.externalLinks;
    final linkSourceMap = linkData.linkSourceMap;
    final totalInternalLinksCount = linkData.totalInternalLinksCount;
    final totalExternalLinksCount = linkData.totalExternalLinksCount;
    final pagesScanned = linkData.pagesScanned;

    // ========================================================================
    // STEP 3 & 4: Check internal and external links for broken pages
    // ========================================================================
    final validator = LinkValidator(
      httpClient: _httpHelper,
      userId: _currentUserId!,
      siteUrl: site.url,
    );
    final brokenLinks = await validator.checkAllLinks(
      siteId: site.id,
      internalLinks: internalLinks,
      externalLinks: externalLinks,
      linkSourceMap: linkSourceMap,
      checkExternalLinks: checkExternalLinks,
      startIndex: startIndex,
      pagesScanned: pagesScanned,
      totalPagesInSitemap: totalPagesInSitemap,
      onProgress: onProgress,
      onExternalLinksProgress: onExternalLinksProgress,
      shouldCancel: shouldCancel,
    );

    // ========================================================================
    // STEP 5: Merge broken links with previous results (if continuing)
    // ========================================================================
    final allBrokenLinks = _mergeBrokenLinks(
      brokenLinks,
      previousBrokenLinks,
      continueFromLastScan,
    );

    // ========================================================================
    // STEP 6: Create and save result to Firestore
    // ========================================================================
    return await _createAndSaveResult(
      site,
      sitemapStatusCode,
      endIndex,
      scanCompleted,
      totalPagesInSitemap,
      totalInternalLinksCount,
      totalExternalLinksCount,
      allBrokenLinks,
      previousResult,
      continueFromLastScan,
      startTime,
    );
  }

  /// Check if two URLs are from the same domain
  bool _isSameDomain(Uri url1, Uri url2) {
    // Android emulator special case: treat localhost and 10.0.2.2 as the same domain
    final host1 = _normalizeEmulatorHost(url1.host);
    final host2 = _normalizeEmulatorHost(url2.host);
    return host1 == host2;
  }

  /// Normalize Android emulator special addresses
  String _normalizeEmulatorHost(String host) {
    // Treat 10.0.2.2 (Android emulator's host machine) as localhost
    if (host == '10.0.2.2') return 'localhost';
    return host;
  }

  /// Build full URL from base URL and path
  /// If path is already a full URL, return it as-is
  /// Otherwise, combine base URL with the path
  String _buildFullUrl(Uri baseUrl, String path) {
    // Check if path is already a full URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // Combine base URL with path
    // Remove trailing slash from base, and leading slash from path if present
    final baseStr = baseUrl.toString().replaceAll(RegExp(r'/$'), '');
    final pathStr = path.startsWith('/') ? path : '/$path';
    return '$baseStr$pathStr';
  }

  /// Get broken links for a specific result
  Future<List<BrokenLink>> getBrokenLinks(String resultId) async {
    if (_currentUserId == null) return [];
    return _repo.getBrokenLinks(resultId);
  }

  /// Get latest check result for a site
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) async {
    if (_currentUserId == null) return null;
    return _repo.getLatestCheckResult(siteId);
  }

  /// Get check results history for a site
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 50,
  }) async {
    if (_currentUserId == null) return [];
    return _repo.getCheckResults(siteId, limit: limit);
  }

  /// Get all check results across all sites
  Future<List<LinkCheckResult>> getAllCheckResults({int limit = 50}) async {
    if (_currentUserId == null) return [];
    return _repo.getAllCheckResults(limit: limit);
  }

  /// Delete all check results for a site (useful for cleanup)
  Future<void> deleteAllCheckResults(String siteId) async {
    if (_currentUserId == null) return;
    await _repo.deleteAllCheckResults(siteId);
  }

  /// Delete a specific link check result by document ID
  Future<void> deleteLinkCheckResult(String resultId) async {
    if (_currentUserId == null) return;
    await _repo.deleteLinkCheckResult(resultId);
  }

  /// Filter out URLs that match excluded paths
  ///
  /// This method filters URLs based on a list of excluded path prefixes.
  /// Paths are matched against the URL's path component using prefix matching.
  ///
  /// **Path Normalization:**
  /// - Excluded paths are automatically prefixed with '/' if not present
  /// - Example: 'tags/' becomes '/tags/' for matching
  ///
  /// **Matching Behavior:**
  /// - Uses prefix matching (startsWith) on the URL path
  /// - Excludes all nested paths under the excluded prefix
  /// - Example: Excluding '/tags/' will filter:
  ///   - https://example.com/tags/tag-1
  ///   - https://example.com/tags/tag-1/page-2
  ///   - https://example.com/tags/anything/nested
  ///
  /// **Parameters:**
  /// - [urls]: List of URLs to filter
  /// - [excludedPaths]: List of path prefixes to exclude (e.g., ['tags/', 'categories/'])
  ///
  /// **Returns:**
  /// A filtered list containing only URLs that don't match any excluded path prefix
  ///
  // ==========================================================================
  // Private helper methods for checkSiteLinks (extracted for better readability)
  // ==========================================================================

  /// Load sitemap URLs and check accessibility
  /// Returns the list of URLs to scan, total count, and HTTP status code
  Future<SitemapLoadResult> _loadSitemapUrls(
    Site site,
    Uri baseUrl,
    Uri originalBaseUrl,
    void Function(int? statusCode)? onSitemapStatusUpdate,
  ) async {
    List<Uri> allInternalPages = [];
    int? sitemapStatusCode;

    if (site.sitemapUrl != null && site.sitemapUrl!.isNotEmpty) {
      try {
        final fullSitemapUrl = _buildFullUrl(baseUrl, site.sitemapUrl!);

        try {
          final convertedUrl = UrlHelper.convertLocalhostForPlatform(
            fullSitemapUrl,
          );
          final headCheck = await _httpHelper.checkUrlHead(convertedUrl);
          sitemapStatusCode = headCheck.statusCode;

          onSitemapStatusUpdate?.call(sitemapStatusCode);

          if (sitemapStatusCode == 200) {
            allInternalPages = await _sitemapParser.fetchSitemapUrls(
              fullSitemapUrl,
              _httpHelper.checkUrlHead,
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
  Future<PreviousScanData> _loadPreviousScanData(
    String siteId,
    bool continueFromLastScan,
    int startIndex,
  ) async {
    if (!continueFromLastScan || startIndex == 0) {
      return const PreviousScanData(result: null, brokenLinks: <BrokenLink>[]);
    }

    final previousResult = await getLatestCheckResult(siteId);
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
  ScanRange _calculateScanRange(List<Uri> allPages, int startIndex) {
    const maxPagesToScan = 100;
    final remainingPageLimit = _pageLimit - startIndex;
    final actualPagesToScan = maxPagesToScan.clamp(0, remainingPageLimit);

    final endIndex = (startIndex + actualPagesToScan).clamp(0, allPages.length);
    final pagesToScan = allPages.sublist(startIndex, endIndex);
    final scanCompleted = endIndex >= allPages.length || endIndex >= _pageLimit;

    return ScanRange(
      pagesToScan: pagesToScan,
      endIndex: endIndex,
      scanCompleted: scanCompleted,
    );
  }

  /// Scan pages and extract all links (internal and external)
  Future<LinkExtractionResult> _scanPagesAndExtractLinks(
    List<Uri> pagesToScan,
    Uri originalBaseUrl,
    int startIndex,
    int totalPagesInSitemap,
    void Function(int checked, int total)? onProgress,
    bool Function()? shouldCancel,
  ) async {
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

      final htmlContent = await _httpHelper.fetchHtmlContent(pageUrl);
      if (htmlContent == null) continue;

      final links = _httpHelper.extractLinks(htmlContent, page);

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

  /// Merge broken links with previous scan results
  List<BrokenLink> _mergeBrokenLinks(
    List<BrokenLink> newBrokenLinks,
    List<BrokenLink> previousBrokenLinks,
    bool continueFromLastScan,
  ) {
    if (continueFromLastScan && previousBrokenLinks.isNotEmpty) {
      return [...previousBrokenLinks, ...newBrokenLinks];
    }
    return newBrokenLinks;
  }

  /// Create and save scan result to Firestore
  Future<LinkCheckResult> _createAndSaveResult(
    Site site,
    int? sitemapStatusCode,
    int endIndex,
    bool scanCompleted,
    int totalPagesInSitemap,
    int totalInternalLinksCount,
    int totalExternalLinksCount,
    List<BrokenLink> allBrokenLinks,
    LinkCheckResult? previousResult,
    bool continueFromLastScan,
    DateTime startTime,
  ) async {
    final endTime = DateTime.now();
    final newLastScannedPageIndex = scanCompleted ? 0 : endIndex;

    // Calculate cumulative statistics
    final previousTotalLinks = previousResult?.totalLinks ?? 0;
    final previousInternalLinks = previousResult?.internalLinks ?? 0;
    final previousExternalLinks = previousResult?.externalLinks ?? 0;

    final totalLinksCount = totalInternalLinksCount + totalExternalLinksCount;
    final cumulativeTotalLinks = continueFromLastScan && previousResult != null
        ? previousTotalLinks + totalLinksCount
        : totalLinksCount;
    final cumulativeInternalLinks =
        continueFromLastScan && previousResult != null
        ? previousInternalLinks + totalInternalLinksCount
        : totalInternalLinksCount;
    final cumulativeExternalLinks =
        continueFromLastScan && previousResult != null
        ? previousExternalLinks + totalExternalLinksCount
        : totalExternalLinksCount;

    final result = LinkCheckResult(
      siteId: site.id,
      checkedUrl: site.url,
      checkedSitemapUrl: site.sitemapUrl,
      sitemapStatusCode: sitemapStatusCode,
      timestamp: DateTime.now(),
      totalLinks: cumulativeTotalLinks,
      brokenLinks: allBrokenLinks.length,
      internalLinks: cumulativeInternalLinks,
      externalLinks: cumulativeExternalLinks,
      scanDuration: endTime.difference(startTime),
      pagesScanned: endIndex,
      totalPagesInSitemap: totalPagesInSitemap,
      scanCompleted: scanCompleted,
      newLastScannedPageIndex: newLastScannedPageIndex,
    );

    // Save to Firestore
    final resultId = await _repo.saveResult(result);

    // Save broken links as subcollection
    await _repo.saveBrokenLinks(resultId, allBrokenLinks);

    // Cleanup old results (async, non-blocking)
    _repo.cleanupOldResults(site.id).catchError((error) {
      _logger.e('Failed to cleanup old link check results', error: error);
    });

    // Return result with Firestore document ID
    return LinkCheckResult(
      id: resultId,
      siteId: result.siteId,
      checkedUrl: result.checkedUrl,
      checkedSitemapUrl: result.checkedSitemapUrl,
      sitemapStatusCode: result.sitemapStatusCode,
      timestamp: result.timestamp,
      totalLinks: result.totalLinks,
      brokenLinks: result.brokenLinks,
      internalLinks: result.internalLinks,
      externalLinks: result.externalLinks,
      scanDuration: result.scanDuration,
      pagesScanned: result.pagesScanned,
      totalPagesInSitemap: result.totalPagesInSitemap,
      scanCompleted: result.scanCompleted,
      newLastScannedPageIndex: result.newLastScannedPageIndex,
    );
  }

  /// **Example:**
  /// ```dart
  /// final urls = [
  ///   Uri.parse('https://example.com/posts/article-1'),
  ///   Uri.parse('https://example.com/tags/tag-1'),
  ///   Uri.parse('https://example.com/categories/cat-1'),
  /// ];
  /// final filtered = _filterExcludedPaths(urls, ['tags/', 'categories/']);
  /// // Result: Only the posts URL remains
  /// ```
  List<Uri> _filterExcludedPaths(List<Uri> urls, List<String> excludedPaths) {
    if (excludedPaths.isEmpty) return urls;

    return urls.where((url) {
      final path = url.path;

      // Check if the path matches any of the excluded paths
      for (final excludedPath in excludedPaths) {
        // Handle wildcard pattern (e.g., */admin/)
        if (excludedPath.startsWith('*/')) {
          final pattern = excludedPath.substring(2); // Remove the leading */
          // Check if the pattern appears as a complete path segment
          // This ensures */admin/ matches /blog/admin/ but not /administrator/
          final pathSegments = path.split('/');
          if (pathSegments.any(
            (segment) => segment == pattern.replaceAll('/', ''),
          )) {
            return false; // Exclude this URL
          }
        } else {
          // Handle simple prefix pattern (e.g., tags/ or /tags/)
          final normalizedExcludedPath = excludedPath.startsWith('/')
              ? excludedPath
              : '/$excludedPath';

          if (path.startsWith(normalizedExcludedPath)) {
            return false; // Exclude this URL
          }
        }
      }

      return true; // Include this URL
    }).toList();
  }
}
