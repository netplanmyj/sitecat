import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';
import 'package:xml/xml.dart' as xml;
import '../models/broken_link.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../utils/url_helper.dart';
import '../utils/url_encoding_utils.dart';
import 'link_checker/models.dart';

/// Service for checking broken links on websites
class LinkCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _httpClient = http.Client();
  final Logger _logger = Logger();

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

  // Collection references (hierarchical structure)
  CollectionReference _resultsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('linkCheckResults');

  // Broken links as subcollection under linkCheckResults
  CollectionReference _brokenLinksCollection(String userId, String resultId) =>
      _resultsCollection(userId).doc(resultId).collection('brokenLinks');

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
    final brokenLinks = await _checkAllLinks(
      site,
      internalLinks,
      externalLinks,
      linkSourceMap,
      checkExternalLinks,
      startIndex,
      pagesScanned,
      totalPagesInSitemap,
      onProgress,
      onExternalLinksProgress,
      shouldCancel,
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

  /// Check URL with HEAD request before fetching content
  Future<({int statusCode, String? contentType})> _checkUrlHead(
    String url,
  ) async {
    try {
      final response = await _httpClient
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      final contentType = response.headers['content-type']?.toLowerCase();
      return (statusCode: response.statusCode, contentType: contentType);
    } catch (e) {
      return (statusCode: 0, contentType: null);
    }
  }

  /// Fetch HTML content from a URL (with HEAD pre-check)
  Future<String?> _fetchHtmlContent(String url) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(url);

      // Step 1: HEAD request to check status and content type
      final headCheck = await _checkUrlHead(convertedUrl);

      // Skip if not OK status
      if (headCheck.statusCode != 200) {
        return null;
      }

      // Skip if not HTML content
      final contentType = headCheck.contentType;
      if (contentType != null && !contentType.contains('text/html')) {
        return null;
      }

      // Step 2: GET request to fetch content
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch URLs from sitemap.xml (supports up to 2 levels of sitemap index)
  Future<List<Uri>> _fetchSitemapUrls(String sitemapUrl) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(sitemapUrl);

      // Step 1: HEAD request to check status and content type
      final headCheck = await _checkUrlHead(convertedUrl);

      if (headCheck.statusCode != 200) {
        throw Exception('Sitemap not accessible: ${headCheck.statusCode}');
      }

      // Verify it's XML content
      final contentType = headCheck.contentType;
      if (contentType != null &&
          !contentType.contains('xml') &&
          !contentType.contains('text/plain')) {
        throw Exception('Invalid sitemap content type: $contentType');
      }

      // Step 2: GET request to fetch sitemap content
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sitemap: ${response.statusCode}');
      }

      // Parse XML
      final document = xml.XmlDocument.parse(response.body);

      // Check if this is a sitemap index (contains <sitemap> elements)
      final sitemapElements = document.findAllElements('sitemap');

      if (sitemapElements.isNotEmpty) {
        // This is a sitemap index - fetch URLs from child sitemaps
        final allUrls = <Uri>[];

        for (final sitemapElement in sitemapElements) {
          final locElement = sitemapElement.findElements('loc').firstOrNull;
          if (locElement != null) {
            final childSitemapUrl = locElement.innerText.trim();
            if (childSitemapUrl.isNotEmpty) {
              try {
                // Fetch URLs from child sitemap (without HEAD check)
                final childUrls = await _parseSitemapXml(childSitemapUrl);
                allUrls.addAll(childUrls);

                // Limit total URLs to avoid excessive processing
                if (allUrls.length >= 200) {
                  break;
                }
              } catch (e) {
                // Skip this child sitemap if it fails
                continue;
              }
            }
          }
        }

        return allUrls;
      } else {
        // This is a regular sitemap - extract URLs directly from current document
        return _extractUrlsFromSitemapDocument(document);
      }
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
  }

  /// Parse a sitemap XML directly from a URL (used for child sitemaps)
  Future<List<Uri>> _parseSitemapXml(String sitemapUrl) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(sitemapUrl);

      // Add longer delay to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 2000));

      // Use shared client instead of creating new one
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sitemap: ${response.statusCode}');
      }

      final document = xml.XmlDocument.parse(response.body);
      return _extractUrlsFromSitemapDocument(document);
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
  }

  /// Extract URLs from a parsed sitemap XML document
  List<Uri> _extractUrlsFromSitemapDocument(xml.XmlDocument document) {
    final urlElements = document.findAllElements('url');
    final normalizedUrls =
        <String, Uri>{}; // Use Map to deduplicate by normalized key

    for (final urlElement in urlElements) {
      final locElement = urlElement.findElements('loc').firstOrNull;
      if (locElement != null) {
        final urlString = locElement.innerText.trim();
        if (urlString.isNotEmpty) {
          try {
            final uri = Uri.parse(urlString);
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              // Normalize URL: remove fragment, lowercase scheme/host, and remove trailing slash
              final normalizedUri = _normalizeSitemapUrl(uri);
              final normalizedKey = normalizedUri.toString();

              // Store only unique URLs (Map handles deduplication automatically)
              normalizedUrls[normalizedKey] = normalizedUri;
            }
          } catch (e) {
            // Skip invalid URLs
          }
        }
      }
    }

    return normalizedUrls.values.toList();
  }

  /// Normalize sitemap URL by removing fragment, normalizing scheme/host to lowercase, and removing trailing slash
  Uri _normalizeSitemapUrl(Uri uri) {
    // Remove fragment (#section)
    final uriWithoutFragment = uri.removeFragment();

    // Normalize scheme and host to lowercase (case-insensitive per RFC 3986)
    final normalizedScheme = uriWithoutFragment.scheme.toLowerCase();
    final normalizedHost = uriWithoutFragment.host.toLowerCase();

    // Remove trailing slash from path (but keep "/" for root)
    String path = uriWithoutFragment.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Reconstruct URI with normalized components
    return uriWithoutFragment.replace(
      scheme: normalizedScheme,
      host: normalizedHost,
      path: path,
    );
  }

  /// Extract links from HTML content
  List<Uri> _extractLinks(String htmlContent, Uri baseUrl) {
    final document = html_parser.parse(htmlContent);
    final linkElements = document.querySelectorAll('a[href]');

    final links = <Uri>[];
    for (final element in linkElements) {
      final href = element.attributes['href'];
      if (href == null || href.isEmpty) continue;

      // Skip anchor links and javascript links
      if (href.startsWith('#') || href.startsWith('javascript:')) continue;

      try {
        // Resolve relative URLs
        final uri = baseUrl.resolve(href);
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          // Fix mojibake in URL before adding to list
          final fixedUrl = UrlEncodingUtils.fixMojibakeUrl(uri.toString());
          links.add(Uri.parse(fixedUrl));
        }
      } catch (e) {
        // Invalid URL, skip
      }
    }

    // Remove duplicates
    return links.toSet().toList();
  }

  /// Check if a link is broken
  Future<({int statusCode, String? error})?> _checkLink(Uri url) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(
        url.toString(),
      );

      // Use HEAD request for efficiency
      final response = await _httpClient
          .head(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 5));

      // Consider 404 and 5xx as broken
      if (response.statusCode == 404 || response.statusCode >= 500) {
        return (statusCode: response.statusCode, error: null);
      }

      return null; // Link is OK
    } on http.ClientException catch (e) {
      return (statusCode: 0, error: 'Network error: ${e.message}');
    } catch (e) {
      return (statusCode: 0, error: 'Error: $e');
    }
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

  /// Save broken links to Firestore (under a specific result)
  Future<void> _saveBrokenLinks(
    String resultId,
    List<BrokenLink> brokenLinks,
  ) async {
    if (brokenLinks.isEmpty || _currentUserId == null) return;

    final batch = _firestore.batch();
    for (final link in brokenLinks) {
      final docRef = _brokenLinksCollection(_currentUserId!, resultId).doc();
      batch.set(docRef, link.toFirestore());
    }

    await batch.commit();
  }

  /// Get broken links for a specific result
  Future<List<BrokenLink>> getBrokenLinks(String resultId) async {
    if (_currentUserId == null) {
      return [];
    }

    final snapshot = await _brokenLinksCollection(
      _currentUserId!,
      resultId,
    ).orderBy('timestamp', descending: true).get();

    return snapshot.docs.map((doc) => BrokenLink.fromFirestore(doc)).toList();
  }

  /// Delete all broken links for a specific result (when deleting the result)
  Future<void> _deleteResultBrokenLinks(String resultId) async {
    if (_currentUserId == null) return;

    final snapshot = await _brokenLinksCollection(
      _currentUserId!,
      resultId,
    ).get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Get latest check result for a site
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) async {
    if (_currentUserId == null) return null;

    final snapshot = await _resultsCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return LinkCheckResult.fromFirestore(snapshot.docs.first);
  }

  /// Get check results history for a site
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 50,
  }) async {
    if (_currentUserId == null) return [];

    final snapshot = await _resultsCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => LinkCheckResult.fromFirestore(doc))
        .toList();
  }

  /// Get all check results across all sites
  Future<List<LinkCheckResult>> getAllCheckResults({int limit = 50}) async {
    if (_currentUserId == null) return [];

    final snapshot = await _resultsCollection(
      _currentUserId!,
    ).orderBy('timestamp', descending: true).limit(limit).get();

    return snapshot.docs
        .map((doc) => LinkCheckResult.fromFirestore(doc))
        .toList();
  }

  /// Delete all check results for a site (useful for cleanup)
  Future<void> deleteAllCheckResults(String siteId) async {
    if (_currentUserId == null) return;

    final snapshot = await _resultsCollection(
      _currentUserId!,
    ).where('siteId', isEqualTo: siteId).get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Delete a specific link check result by document ID
  Future<void> deleteLinkCheckResult(String resultId) async {
    if (_currentUserId == null) return;

    // Delete all broken links in the subcollection first
    await _deleteResultBrokenLinks(resultId);

    // Delete the result document
    await _resultsCollection(_currentUserId!).doc(resultId).delete();
  }

  /// Cleanup old link check results for a site (respects premium/free limits)
  Future<void> _cleanupOldResults(String siteId) async {
    if (_currentUserId == null) return;

    try {
      // Get all results for the site
      final querySnapshot = await _resultsCollection(_currentUserId!)
          .where('siteId', isEqualTo: siteId)
          .orderBy('timestamp', descending: true)
          .get();

      // If we have fewer results than the limit, no cleanup needed
      if (querySnapshot.docs.length <= _historyLimit) return;

      // Delete results beyond the limit (including their broken links subcollections)
      final batch = _firestore.batch();
      for (int i = _historyLimit; i < querySnapshot.docs.length; i++) {
        final docRef = querySnapshot.docs[i].reference;

        // Delete broken links subcollection
        final brokenLinksSnapshot = await docRef
            .collection('brokenLinks')
            .get();
        for (final brokenLinkDoc in brokenLinksSnapshot.docs) {
          batch.delete(brokenLinkDoc.reference);
        }

        // Delete the result document itself
        batch.delete(docRef);
      }

      await batch.commit();
      _logger.i(
        'Cleaned up ${querySnapshot.docs.length - _historyLimit} old link check results for site $siteId',
      );
    } catch (e) {
      _logger.e('Error during cleanup of old link check results', error: e);
      rethrow;
    }
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
          final headCheck = await _checkUrlHead(convertedUrl);
          sitemapStatusCode = headCheck.statusCode;

          onSitemapStatusUpdate?.call(sitemapStatusCode);

          if (sitemapStatusCode == 200) {
            allInternalPages = await _fetchSitemapUrls(fullSitemapUrl);
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

      final htmlContent = await _fetchHtmlContent(pageUrl);
      if (htmlContent == null) continue;

      final links = _extractLinks(htmlContent, page);

      for (final link in links) {
        final normalizedLink = _normalizeSitemapUrl(link);
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

  /// Check all links (internal and external) for broken pages
  Future<List<BrokenLink>> _checkAllLinks(
    Site site,
    Set<Uri> internalLinks,
    Set<Uri> externalLinks,
    Map<String, List<String>> linkSourceMap,
    bool checkExternalLinks,
    int startIndex,
    int pagesScanned,
    int totalPagesInSitemap,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    bool Function()? shouldCancel,
  ) async {
    final brokenLinks = <BrokenLink>[];
    final internalLinksList = internalLinks.toList();
    final totalInternalLinks = internalLinksList.length;

    final externalLinksCount = checkExternalLinks ? externalLinks.length : 0;
    final totalAllLinks = totalInternalLinks + externalLinksCount;
    int checkedInternal = 0;

    // Report initial state
    if (totalAllLinks > 0) {
      onExternalLinksProgress?.call(0, totalAllLinks);
    }

    // Check internal links
    for (final link in internalLinksList) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final linkUrl = link.toString();

      if (checkedInternal > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final isBroken = await _checkLink(link);

      if (isBroken != null) {
        brokenLinks.add(
          BrokenLink(
            id: '',
            siteId: site.id,
            userId: _currentUserId!,
            timestamp: DateTime.now(),
            url: linkUrl,
            foundOn: linkSourceMap[linkUrl]?.first ?? site.url,
            statusCode: isBroken.statusCode,
            error: isBroken.error,
            linkType: LinkType.internal,
          ),
        );
      }

      checkedInternal++;
      if (totalAllLinks > 0) {
        onExternalLinksProgress?.call(checkedInternal, totalAllLinks);
      }
    }

    // Check external links (if requested)
    if (checkExternalLinks) {
      final cumulativePagesScanned = startIndex + pagesScanned;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      final externalLinksList = externalLinks.toList();
      int checkedExternal = 0;

      for (final link in externalLinksList) {
        if (shouldCancel?.call() ?? false) {
          break;
        }

        final linkUrl = link.toString();

        if (checkedExternal > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final isBroken = await _checkLink(link);

        if (isBroken != null) {
          brokenLinks.add(
            BrokenLink(
              id: '',
              siteId: site.id,
              userId: _currentUserId!,
              timestamp: DateTime.now(),
              url: linkUrl,
              foundOn: linkSourceMap[linkUrl]?.first ?? site.url,
              statusCode: isBroken.statusCode,
              error: isBroken.error,
              linkType: LinkType.external,
            ),
          );
        }

        checkedExternal++;
        final totalChecked = checkedInternal + checkedExternal;
        onExternalLinksProgress?.call(totalChecked, totalAllLinks);
      }
    }

    return brokenLinks;
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
    final docRef = await _resultsCollection(
      _currentUserId!,
    ).add(result.toFirestore());
    final resultId = docRef.id;

    // Save broken links as subcollection
    await _saveBrokenLinks(resultId, allBrokenLinks);

    // Cleanup old results (async, non-blocking)
    _cleanupOldResults(site.id).catchError((error) {
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
