import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Service for checking broken links on websites
class LinkCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _httpClient = http.Client();
  final Logger _logger = Logger();

  // Helper classes
  late final LinkCheckerHttpClient _httpHelper;
  late final SitemapParser _sitemapParser;
  late final ScanOrchestrator _orchestrator;
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

  /// Set history limit based on premium status
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
    final endIndex = scanRange.endIndex;
    final scanCompleted = scanRange.scanCompleted;

    // ========================================================================
    // STEP 2: Scan pages and extract all links
    // ========================================================================
    final linkData = await _extractor.scanPagesAndExtractLinks(
      pagesToScan: pagesToScan,
      originalBaseUrl: originalBaseUrl,
      startIndex: startIndex,
      totalPagesInSitemap: totalPagesInSitemap,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
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
    final allBrokenLinks = _resultBuilder.mergeBrokenLinks(
      newBrokenLinks: brokenLinks,
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
      endIndex: endIndex,
      scanCompleted: scanCompleted,
      totalPagesInSitemap: totalPagesInSitemap,
      totalInternalLinksCount: totalInternalLinksCount,
      totalExternalLinksCount: totalExternalLinksCount,
      allBrokenLinks: allBrokenLinks,
      previousResult: previousResult,
      continueFromLastScan: continueFromLastScan,
      startTime: startTime,
    );
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
}
