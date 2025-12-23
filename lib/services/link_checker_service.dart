import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../utils/url_helper.dart';
import 'link_checker/http_client.dart';
import 'link_checker/link_extractor.dart';
import 'link_checker/link_validator.dart';
import 'link_checker/models.dart'; // + add types (SitemapLoadResult, PreviousScanData)
import 'link_checker/result_builder.dart';
import 'link_checker/result_repository.dart';
import 'link_checker/scan_orchestrator.dart';
import 'link_checker/sitemap_parser.dart';

abstract class LinkCheckerClient {
  void setHistoryLimit(bool isPremium);
  void setPageLimit(bool isPremium);
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks,
    bool continueFromLastScan,
    int? precalculatedPageCount,
    List<Uri>? cachedSitemapUrls,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    void Function(int? statusCode)? onSitemapStatusUpdate,
    bool Function()? shouldCancel,
  });
  Future<int?> loadSitemapPageCount(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  });
  Future<List<Uri>?> loadSitemapUrls(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  });
  Future<List<BrokenLink>> getBrokenLinks(String resultId);
  Future<LinkCheckResult?> getLatestCheckResult(String siteId);
  Future<List<LinkCheckResult>> getCheckResults(String siteId, {int limit});
  Future<List<LinkCheckResult>> getAllCheckResults({int limit});
  Future<void> deleteLinkCheckResult(String resultId);
  Future<void> saveInterruptedResult(LinkCheckResult result);
}

/// Service for checking broken links on websites
class LinkCheckerService implements LinkCheckerClient {
  static const String _firebaseAppName = 'sitecat-current';

  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final http.Client _httpClient;
  late final Logger _logger;

  // Helper classes
  late final LinkCheckerHttpClient _httpHelper;
  late SitemapParser _sitemapParser;
  late ScanOrchestrator _orchestrator;
  late LinkExtractor _extractor;
  late ResultBuilder _resultBuilder;
  LinkCheckResultRepository? _repository;
  String? _repositoryUserId;

  // History limit for cleanup (can be set based on premium status)
  int _historyLimit = AppConstants.freePlanHistoryLimit;

  // Page limit for scanning (can be set based on premium status)
  int _pageLimit = AppConstants.freePlanPageLimit;

  LinkCheckerService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    Logger? logger,
  }) {
    FirebaseApp app;
    try {
      app = Firebase.app(_firebaseAppName);
    } on FirebaseException {
      if (Firebase.apps.isNotEmpty) {
        // Fallback to default app if named app not initialized yet
        app = Firebase.app();
      } else {
        // No Firebase app initialized; surface a clear error
        throw FirebaseException(
          plugin: 'firebase_core',
          message:
              'Firebase has not been initialized. Initialize Firebase before creating LinkCheckerService.',
        );
      }
    }
    _firestore = firestore ?? FirebaseFirestore.instanceFor(app: app);
    _auth = auth ?? FirebaseAuth.instanceFor(app: app);
    _httpClient = httpClient ?? http.Client();
    _logger = logger ?? Logger();

    _httpHelper = LinkCheckerHttpClient(_httpClient);
    _sitemapParser = SitemapParser(_httpClient, maxPageLimit: _pageLimit);
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

  // Helper to check premium status without coupling to page limit semantics
  bool get _isPremiumUser => _pageLimit != AppConstants.freePlanPageLimit;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

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
    // Recreate SitemapParser with new page limit
    _sitemapParser = SitemapParser(_httpClient, maxPageLimit: _pageLimit);
    // Recreate orchestrator so new page limit is applied to subsequent scans
    _orchestrator = ScanOrchestrator(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
      pageLimit: _pageLimit,
    );
    // Recreate extractor with new sitemap parser
    _extractor = LinkExtractor(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
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
    bool continueFromLastScan = false,
    int? precalculatedPageCount,
    List<Uri>? cachedSitemapUrls,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    void Function(int? statusCode)? onSitemapStatusUpdate,
    bool Function()? shouldCancel,
  }) async {
    final startTime = DateTime.now();

    // STEP 0: Initialize and validate
    // final (originalBaseUrl, baseUrl, siteForScanning) =
    //     await _initializeAndValidate(site, continueFromLastScan);
    final init = await _initializeAndValidate(site, continueFromLastScan);
    final originalBaseUrl = init.$1;
    final baseUrl = init.$2;
    final siteForScanning = init.$3;

    // STEP 1: Quick check base URL
    // final (baseUrlStatusCode, baseUrlResponseTime, baseUrlIsUp) =
    //     await _performQuickCheck(baseUrl, site.url);
    final qc = await _performQuickCheck(baseUrl, site.url);
    final baseUrlStatusCode = qc.$1;
    final baseUrlResponseTime = qc.$2;
    final baseUrlIsUp = qc.$3;

    // STEP 1-1c: Load sitemap and prepare data
    // final (
    //   SitemapLoadResult sitemapData,
    //   int startIndex,
    //   PreviousScanData previousData,
    //   List<Uri> pagesToScan,
    //   bool scanRangeCompleted,
    // ) = await _loadSitemapAndPrepareData(...)
    final prep = await _loadSitemapAndPrepareData(
      siteForScanning,
      baseUrl,
      originalBaseUrl,
      continueFromLastScan,
      precalculatedPageCount,
      cachedSitemapUrls,
      onSitemapStatusUpdate,
    );
    final SitemapLoadResult sitemapData = prep.$1;
    final int startIndex = prep.$2;
    final PreviousScanData previousData = prep.$3;
    final List<Uri> pagesToScan = prep.$4;
    final bool scanRangeCompleted = prep.$5;

    // STEP 2-4: Scan pages and validate links
    // final (
    //   allInternalLinks,
    //   allExternalLinks,
    //   allLinkSourceMap,
    //   allBrokenLinks,
    //   pagesCompleted,
    //   pagesScanned,
    // ) = await _scanPagesAndValidateLinks(...)
    final scanRes = await _scanPagesAndValidateLinks(
      pagesToScan,
      site.id,
      originalBaseUrl,
      checkExternalLinks,
      continueFromLastScan,
      onProgress,
      onExternalLinksProgress,
      shouldCancel,
      startIndex,
      sitemapData.totalPages,
    );
    final Set<Uri> allInternalLinks = scanRes.$1;
    final Set<Uri> allExternalLinks = scanRes.$2;
    // allLinkSourceMap retained internally for potential future use
    // final Map<String, List<String>> allLinkSourceMap = scanRes.$3;
    final List<BrokenLink> allBrokenLinks = scanRes.$4;
    final int pagesCompleted = scanRes.$5;
    // final int pagesScanned = scanRes.$6;

    // STEP 5-6: Build and save result
    return await _buildAndSaveResult(
      site,
      sitemapData,
      startIndex,
      pagesCompleted,
      pagesToScan.length,
      scanRangeCompleted,
      allInternalLinks,
      allExternalLinks,
      allBrokenLinks,
      previousData,
      continueFromLastScan,
      startTime,
      baseUrlStatusCode,
      baseUrlResponseTime,
      baseUrlIsUp,
    );
  }

  /// Initialize and validate scan preconditions
  /// Returns: (originalBaseUrl, baseUrl, siteForScanning)
  Future<(Uri, Uri, Site)> _initializeAndValidate(
    Site site,
    bool continueFromLastScan,
  ) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check links');
    }

    final originalBaseUrl = Uri.parse(site.url);
    final baseUrl = Uri.parse(UrlHelper.convertLocalhostForPlatform(site.url));

    _orchestrator = ScanOrchestrator(
      httpClient: _httpHelper,
      sitemapParser: _sitemapParser,
      pageLimit: _pageLimit,
    );
    // Excluded paths (premium feature) summary
    // - Free users: excludedPaths are ignored to keep the feature premium-only
    // - Premium users: excludedPaths are applied downstream during sitemap URL filtering
    //   in ScanOrchestrator._filterExcludedPaths().
    //   Rules (brief):
    //   * Paths are normalized to start with '/'
    //   * Prefix match: '/admin' excludes '/admin', '/admin/', '/admin/users'
    //   * Wildcard segment: '*/admin/' excludes any URL that contains a path
    //     segment exactly equal to 'admin' (e.g., '/v1/admin/users')
    //   * Matching is path-based, not regex; scheme/host are not considered here
    //   See lib/services/link_checker/scan_orchestrator.dart::_filterExcludedPaths
    //   for the authoritative logic and more details.
    final siteForScanning = _isPremiumUser
        ? site
        : site.copyWith(excludedPaths: []);

    return (originalBaseUrl, baseUrl, siteForScanning);
  }

  /// Perform quick check on base URL (STEP 0)
  /// Returns: (statusCode, responseTime, isUp)
  Future<(int?, int?, bool?)> _performQuickCheck(
    Uri baseUrl,
    String siteUrl,
  ) async {
    int? baseUrlStatusCode;
    int? baseUrlResponseTime;
    bool? baseUrlIsUp;

    try {
      final quickCheckStart = DateTime.now();
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(
        baseUrl.toString(),
      );
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 10));
      final quickCheckEnd = DateTime.now();

      baseUrlStatusCode = response.statusCode;
      baseUrlResponseTime = quickCheckEnd
          .difference(quickCheckStart)
          .inMilliseconds;
      baseUrlIsUp = baseUrlStatusCode >= 200 && baseUrlStatusCode < 400;

      _logger.d(
        'Quick check for $siteUrl: status=$baseUrlStatusCode, time=${baseUrlResponseTime}ms',
      );
    } catch (e) {
      baseUrlStatusCode = 0;
      baseUrlResponseTime = null;
      baseUrlIsUp = false;
      _logger.e('Quick check failed for $siteUrl: $e');
    }

    return (baseUrlStatusCode, baseUrlResponseTime, baseUrlIsUp);
  }

  /// Load sitemap and prepare scan data (STEP 1-1c)
  /// Returns: (sitemapData, startIndex, previousData, pagesToScan, scanCompleted)
  Future<(SitemapLoadResult, int, PreviousScanData, List<Uri>, bool)>
  _loadSitemapAndPrepareData(
    Site siteForScanning,
    Uri baseUrl,
    Uri originalBaseUrl,
    bool continueFromLastScan,
    int? precalculatedPageCount,
    List<Uri>? cachedSitemapUrls,
    void Function(int? statusCode)? onSitemapStatusUpdate,
  ) async {
    final sitemapData = await _orchestrator.loadSitemapUrls(
      site: siteForScanning,
      baseUrl: baseUrl,
      originalBaseUrl: originalBaseUrl,
      onSitemapStatusUpdate: onSitemapStatusUpdate,
      precalculatedPageCount: precalculatedPageCount,
      cachedUrls: cachedSitemapUrls,
    );

    final startIndex = continueFromLastScan
        ? siteForScanning.lastScannedPageIndex
        : 0;

    final previousData = await _orchestrator.loadPreviousScanData(
      continueFromLastScan: continueFromLastScan,
      startIndex: startIndex,
      getLatestResult: getLatestCheckResult,
      getBrokenLinks: getBrokenLinks,
      siteId: siteForScanning.id,
    );

    final scanRange = _orchestrator.calculateScanRange(
      allPages: sitemapData.urls,
      startIndex: startIndex,
    );

    return (
      sitemapData,
      startIndex,
      previousData,
      scanRange.pagesToScan,
      scanRange.scanCompleted, // return the correct completion flag
    );
  }

  /// Scan pages and validate links (STEP 2-4)
  /// Returns: (allInternalLinks, allExternalLinks, allLinkSourceMap, allBrokenLinks, pagesCompleted, pagesScanned)
  Future<
    (Set<Uri>, Set<Uri>, Map<String, List<String>>, List<BrokenLink>, int, int)
  >
  _scanPagesAndValidateLinks(
    List<Uri> pagesToScan,
    String siteId,
    Uri originalBaseUrl,
    bool checkExternalLinks,
    bool continueFromLastScan,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    bool Function()? shouldCancel,
    int startIndex,
    int totalPagesInSitemap,
  ) async {
    final validator = LinkValidator(
      httpClient: _httpHelper,
      userId: _currentUserId!,
      siteUrl: originalBaseUrl.toString(),
    );

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
      if (pagesScanned > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final pageExtractionResult = await _extractor.scanAndExtractLinksForPage(
        page: page,
        originalBaseUrl: originalBaseUrl,
        shouldCancel: shouldCancel,
      );

      pagesScanned++;

      if (!pageExtractionResult.wasSuccessful) {
        continue;
      }

      allInternalLinks.addAll(pageExtractionResult.internalLinks);
      allExternalLinks.addAll(pageExtractionResult.externalLinks);

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

      final pageBrokenLinks = await validator.checkLinksFromPage(
        siteId: siteId,
        internalLinks: pageExtractionResult.internalLinks,
        externalLinks: pageExtractionResult.externalLinks,
        linkSourceMap: pageExtractionResult.linkSourceMap,
        checkExternalLinks: checkExternalLinks,
        onExternalLinksProgress: onExternalLinksProgress,
        shouldCancel: shouldCancel,
      );

      allBrokenLinks.addAll(pageBrokenLinks);

      if (shouldCancel?.call() ?? false) {
        break;
      }

      pagesCompleted++;
      final cumulativePagesScanned = startIndex + pagesCompleted;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);
    }

    return (
      allInternalLinks,
      allExternalLinks,
      allLinkSourceMap,
      allBrokenLinks,
      pagesCompleted,
      pagesScanned,
    );
  }

  /// Build and save final result (STEP 5-6)
  Future<LinkCheckResult> _buildAndSaveResult(
    Site site,
    SitemapLoadResult sitemapData, // typed
    int startIndex,
    int pagesCompleted,
    int pagesToScanLength,
    bool scanRangeCompleted, // lowerCamelCase
    Set<Uri> allInternalLinks,
    Set<Uri> allExternalLinks,
    List<BrokenLink> allBrokenLinks,
    PreviousScanData previousData, // typed
    bool continueFromLastScan,
    DateTime startTime,
    int? baseUrlStatusCode,
    int? baseUrlResponseTime,
    bool? baseUrlIsUp,
  ) async {
    final pagesScannedCount = startIndex + pagesCompleted;
    final scanCompleted =
        scanRangeCompleted && pagesCompleted == pagesToScanLength;
    final resumeFromIndex = scanCompleted ? 0 : pagesScannedCount;

    final mergedBrokenLinks = _resultBuilder.mergeBrokenLinks(
      newBrokenLinks: allBrokenLinks,
      previousBrokenLinks: previousData.brokenLinks,
      continueFromLastScan: continueFromLastScan,
    );

    return _resultBuilder.createAndSaveResult(
      userId: _currentUserId!,
      site: site,
      sitemapStatusCode: sitemapData.statusCode,
      pagesScannedCount: pagesScannedCount,
      scanCompleted: scanCompleted,
      resumeFromIndex: resumeFromIndex,
      totalPagesInSitemap: sitemapData.totalPages,
      totalInternalLinksCount: allInternalLinks.length,
      totalExternalLinksCount: allExternalLinks.length,
      allBrokenLinks: mergedBrokenLinks,
      previousResult: previousData.result,
      continueFromLastScan: continueFromLastScan,
      startTime: startTime,
      startIndex: startIndex,
      baseUrlStatusCode: baseUrlStatusCode,
      baseUrlResponseTime: baseUrlResponseTime,
      baseUrlIsUp: baseUrlIsUp,
    );
  }

  // ---------- Concrete implementations for LinkCheckerClient ----------

  @override
  Future<int?> loadSitemapPageCount(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  }) async {
    try {
      final urls = await loadSitemapUrls(
        site,
        onSitemapStatusUpdate: onSitemapStatusUpdate,
      );
      return urls?.length;
    } catch (e) {
      _logger.e('Error loading sitemap page count for ${site.id}: $e');
      return null;
    }
  }

  @override
  Future<List<Uri>?> loadSitemapUrls(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  }) async {
    try {
      final baseUrl = Uri.parse(site.url);
      final originalBaseUrl = baseUrl;

      final sitemapData = await _orchestrator.loadSitemapUrls(
        site: site,
        baseUrl: baseUrl,
        originalBaseUrl: originalBaseUrl,
        onSitemapStatusUpdate: onSitemapStatusUpdate,
      );

      return sitemapData.urls;
    } catch (e) {
      _logger.e('Error loading sitemap URLs for ${site.id}: $e');
      return null;
    }
  }

  @override
  Future<List<BrokenLink>> getBrokenLinks(String resultId) async {
    if (_currentUserId == null) return [];
    return _repo.getBrokenLinks(resultId);
  }

  @override
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) async {
    if (_currentUserId == null) return null;
    return _repo.getLatestCheckResult(siteId);
  }

  @override
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 50,
  }) async {
    if (_currentUserId == null) return [];
    return _repo.getCheckResults(siteId, limit: limit);
  }

  @override
  Future<List<LinkCheckResult>> getAllCheckResults({int limit = 50}) async {
    if (_currentUserId == null) return [];
    return _repo.getAllCheckResults(limit: limit);
  }

  Future<void> deleteAllCheckResults(String siteId) async {
    if (_currentUserId == null) return;
    await _repo.deleteAllCheckResults(siteId);
  }

  @override
  Future<void> deleteLinkCheckResult(String resultId) async {
    if (_currentUserId == null) return;
    await _repo.deleteLinkCheckResult(resultId);
  }

  @override
  Future<void> saveInterruptedResult(LinkCheckResult result) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to save results');
    }
    await _repo.saveResult(result);
  }
}
