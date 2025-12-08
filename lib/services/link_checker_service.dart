import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../utils/url_helper.dart';
import 'link_checker/http_client.dart';
import 'link_checker/sitemap_parser.dart';
import 'link_checker/result_repository.dart';
import 'link_checker/link_validator.dart';
import 'link_checker/scan_orchestrator.dart';
import 'link_checker/link_extractor.dart';
import 'link_checker/result_builder.dart';

abstract class LinkCheckerClient {
  void setHistoryLimit(bool isPremium);
  void setPageLimit(bool isPremium);
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks,
    bool continueFromLastScan,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    void Function(int? statusCode)? onSitemapStatusUpdate,
    bool Function()? shouldCancel,
  });
  Future<List<BrokenLink>> getBrokenLinks(String resultId);
  Future<LinkCheckResult?> getLatestCheckResult(String siteId);
  Future<List<LinkCheckResult>> getCheckResults(String siteId, {int limit});
  Future<List<LinkCheckResult>> getAllCheckResults({int limit});
  Future<void> deleteLinkCheckResult(String resultId);
}

/// Service for checking broken links on websites
class LinkCheckerService implements LinkCheckerClient {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _httpClient = http.Client();
  final Logger _logger = Logger();

  // Helper classes
  late final LinkCheckerHttpClient _httpHelper;
  late final SitemapParser _sitemapParser;
  // Mutable to allow recreation when page limit changes via setPageLimit()
  late ScanOrchestrator _orchestrator;
  late final LinkExtractor _extractor;
  late final ResultBuilder _resultBuilder;
  LinkCheckResultRepository? _repository;
  String? _repositoryUserId;

  LinkCheckerService() {
    _httpHelper = LinkCheckerHttpClient(_httpClient);
    _sitemapParser = SitemapParser(_httpClient);
    _orchestrator = ScanOrchestrator(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
      pageLimit: _pageLimit,
    );
    _extractor = LinkExtractor(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
    );
    _resultBuilder = ResultBuilder(
      firestore: _firestore,
      logger: _logger,
      historyLimit: _historyLimit,
    );
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

  /// Get current page limit (visible for testing)
  @visibleForTesting
  int get pageLimit => _pageLimit;

  /// Get current history limit (visible for testing)
  @visibleForTesting
  int get historyLimit => _historyLimit;

  /// Set history limit based on premium status
  @override
  void setHistoryLimit(bool isPremium) {
    _historyLimit = isPremium
        ? AppConstants.premiumHistoryLimit
        : AppConstants.freePlanHistoryLimit;
    // Recreate ResultBuilder with new history limit
    _resultBuilder = ResultBuilder(
      firestore: _firestore,
      logger: _logger,
      historyLimit: _historyLimit,
    );
  }

  /// Set page limit based on premium status
  @override
  void setPageLimit(bool isPremium) {
    _pageLimit = isPremium
        ? AppConstants.premiumPlanPageLimit
        : AppConstants.freePlanPageLimit;
    // Recreate orchestrator so new page limit is applied to subsequent scans
    _orchestrator = ScanOrchestrator(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
      pageLimit: _pageLimit,
    );
  }

  /// Check all links on a site
  ///
  /// This method performs a comprehensive link check in the following steps:
  /// 1. Load sitemap URLs and check accessibility
  ///    - 1a: Load sitemap URLs from configured sitemap.xml
  ///    - 1b: Load previous scan data (if continuing)
  ///    - 1c: Calculate scan range for this batch
  /// 2. Per-page cycle (for each page in the batch):
  ///    - 2a: Fetch page and extract links (internal & external)
  ///    - 2b: Validate links from that page immediately
  ///    - 2c: Increment pagesCompleted and emit progress
  /// 3. Merge with previous scan results (if continuing)
  /// 4. Create and save the final result to Firestore
  ///
  /// ⚠️ [仕様変更] v1.0.4以降：
  /// - 旧仕様（v1.0.3）: 全ページ抽出 → 全リンク一括検証
  /// - 新仕様（v1.0.4〜）: ページ単位の抽出→検証ループで、Stop時に途中結果を保存可能
  ///
  /// [onSitemapStatusUpdate] is called immediately after checking sitemap accessibility.
  /// The statusCode represents:
  /// - 200: Sitemap is accessible
  /// - 404: Sitemap not found
  /// - 0: Network error occurred
  /// - null: No sitemap configured
  /// This enables real-time UI updates before the site scan completes.
  ///
  /// [shouldCancel] is called periodically to check if scan should be cancelled.
  /// Return true to stop the scan gracefully.
  @override
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
    final sitemapData = await _orchestrator.loadSitemapUrls(
      site: site,
      baseUrl: baseUrl,
      originalBaseUrl: originalBaseUrl,
      onSitemapStatusUpdate: onSitemapStatusUpdate,
    );
    final allInternalPages = sitemapData.urls;
    final totalPagesInSitemap = sitemapData.totalPages;
    final sitemapStatusCode = sitemapData.statusCode;

    // ========================================================================
    // STEP 1b: Load previous scan data (if continuing from last scan)
    // ========================================================================
    final startIndex = continueFromLastScan ? site.lastScannedPageIndex : 0;
    final previousData = await _orchestrator.loadPreviousScanData(
      continueFromLastScan: continueFromLastScan,
      startIndex: startIndex,
      getLatestResult: getLatestCheckResult,
      getBrokenLinks: getBrokenLinks,
      siteId: site.id,
    );
    final previousResult = previousData.result;
    final previousBrokenLinks = previousData.brokenLinks;

    // ========================================================================
    // STEP 1c: Calculate scan range for this batch
    // ========================================================================
    final scanRange = _orchestrator.calculateScanRange(
      allPages: allInternalPages,
      startIndex: startIndex,
    );
    final pagesToScan = scanRange.pagesToScan;

    // ========================================================================
    // STEP 2 & 3-4: Per-page cycle (extract links, validate per page)
    // ========================================================================
    final validator = LinkValidator(
      httpClient: _httpHelper,
      userId: _currentUserId!,
      siteUrl: site.url,
    );

    // Clear cache only when starting a new scan (not when continuing)
    if (!continueFromLastScan) {
      validator.clearCache();
    }

    final allInternalLinks = <Uri>{};
    final allExternalLinks = <Uri>{};
    final allLinkSourceMap = <String, List<String>>{};
    final allBrokenLinks = <BrokenLink>[];

    int pagesCompleted = 0;
    int pagesScanned = 0;

    for (final page in pagesToScan) {
      // Add minimal delay between page fetches (100ms after first page)
      // to avoid overwhelming the server while maintaining performance
      if (pagesScanned > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Step 2a: Fetch page and extract links from this page
      final pageExtractionResult = await _extractor.scanAndExtractLinksForPage(
        page: page,
        originalBaseUrl: originalBaseUrl,
        shouldCancel: shouldCancel,
      );

      pagesScanned++;

      if (!pageExtractionResult.wasSuccessful) {
        // Page fetch failed, but continue to next page
        continue;
      }

      // Accumulate links from all pages
      allInternalLinks.addAll(pageExtractionResult.internalLinks);
      allExternalLinks.addAll(pageExtractionResult.externalLinks);

      // Merge link source map
      for (final entry in pageExtractionResult.linkSourceMap.entries) {
        if (!allLinkSourceMap.containsKey(entry.key)) {
          allLinkSourceMap[entry.key] = entry.value;
        } else {
          allLinkSourceMap[entry.key]!.addAll(
            entry.value.where(
              (url) => !allLinkSourceMap[entry.key]!.contains(url),
            ),
          );
        }
      }

      // Step 3-4: Validate links from this page immediately
      final pageBrokenLinks = await validator.checkLinksFromPage(
        siteId: site.id,
        internalLinks: pageExtractionResult.internalLinks,
        externalLinks: pageExtractionResult.externalLinks,
        linkSourceMap: pageExtractionResult.linkSourceMap,
        checkExternalLinks: checkExternalLinks,
        onExternalLinksProgress: onExternalLinksProgress,
        shouldCancel: shouldCancel,
      );

      allBrokenLinks.addAll(pageBrokenLinks);

      // Increment pagesCompleted and emit progress
      pagesCompleted++;
      final cumulativePagesScanned = startIndex + pagesCompleted;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      // Check for cancellation after completing the current page
      // This ensures the page is fully processed before stopping
      if (shouldCancel?.call() ?? false) {
        break;
      }
    }

    // Use actual scanned pages to set endIndex so we don't skip pages when
    // a scan stops early (e.g., user pressed stop mid-batch).
    final pagesScannedCount = startIndex + pagesCompleted;
    final scanCompleted =
        scanRange.scanCompleted && pagesCompleted == pagesToScan.length;

    // Resume from the next page after the last completed one
    // If scan completed fully, reset to 0 to start fresh next time
    final resumeFromIndex = scanCompleted ? 0 : pagesScannedCount;

    // ========================================================================
    // STEP 5: Merge broken links with previous results (if continuing)
    // ========================================================================
    final mergedBrokenLinks = _resultBuilder.mergeBrokenLinks(
      newBrokenLinks: allBrokenLinks,
      previousBrokenLinks: previousBrokenLinks,
      continueFromLastScan: continueFromLastScan,
    );

    // ========================================================================
    // STEP 6: Create and save result to Firestore
    // ========================================================================
    return await _resultBuilder.createAndSaveResult(
      userId: _currentUserId!,
      site: site,
      sitemapStatusCode: sitemapStatusCode,
      pagesScannedCount: pagesScannedCount,
      scanCompleted: scanCompleted,
      resumeFromIndex: resumeFromIndex,
      totalPagesInSitemap: totalPagesInSitemap,
      totalInternalLinksCount: allInternalLinks.length,
      totalExternalLinksCount: allExternalLinks.length,
      allBrokenLinks: mergedBrokenLinks,
      previousResult: previousResult,
      continueFromLastScan: continueFromLastScan,
      startTime: startTime,
      startIndex: startIndex,
    );
  }

  /// Get broken links for a specific result
  @override
  Future<List<BrokenLink>> getBrokenLinks(String resultId) async {
    if (_currentUserId == null) return [];
    return _repo.getBrokenLinks(resultId);
  }

  /// Get latest check result for a site
  @override
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) async {
    if (_currentUserId == null) return null;
    return _repo.getLatestCheckResult(siteId);
  }

  /// Get check results history for a site
  @override
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 50,
  }) async {
    if (_currentUserId == null) return [];
    return _repo.getCheckResults(siteId, limit: limit);
  }

  /// Get all check results across all sites
  @override
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
  @override
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
}
