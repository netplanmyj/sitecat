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

/// Service for checking broken links on websites
class LinkCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final http.Client _httpClient = http.Client();
  final Logger _logger = Logger();

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references (hierarchical structure)
  CollectionReference _resultsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('linkCheckResults');

  // Broken links as subcollection under linkCheckResults
  CollectionReference _brokenLinksCollection(String userId, String resultId) =>
      _resultsCollection(userId).doc(resultId).collection('brokenLinks');

  /// Check all links on a site
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = true,
    bool continueFromLastScan = false, // Continue from last scanned index
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check links');
    }

    final startTime = DateTime.now();
    // Keep original base URL for domain comparison (sitemap URLs use localhost)
    final originalBaseUrl = Uri.parse(site.url);
    // Converted base URL for actual HTTP requests (Android: localhost -> 10.0.2.2)
    final baseUrl = Uri.parse(UrlHelper.convertLocalhostForPlatform(site.url));

    // Step 1: Get internal pages from sitemap (these are our pages to scan)
    List<Uri> allInternalPages = [];

    if (site.sitemapUrl != null && site.sitemapUrl!.isNotEmpty) {
      try {
        // Build full sitemap URL (combine with base URL if relative path)
        final fullSitemapUrl = _buildFullUrl(baseUrl, site.sitemapUrl!);
        allInternalPages = await _fetchSitemapUrls(fullSitemapUrl);

        // Filter out excluded paths
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
        // Sitemap fetch failed, fall back to checking only the top page
        allInternalPages = [originalBaseUrl];
      }
    } else {
      // No sitemap provided, check only the top page
      allInternalPages = [originalBaseUrl];
    }

    final totalPagesInSitemap = allInternalPages.length;

    // Determine start index (for progressive scanning)
    final startIndex = continueFromLastScan ? site.lastScannedPageIndex : 0;

    // Get previous scan data if continuing
    LinkCheckResult? previousResult;
    List<BrokenLink> previousBrokenLinks = [];
    if (continueFromLastScan && startIndex > 0) {
      previousResult = await getLatestCheckResult(site.id);
      if (previousResult != null) {
        previousBrokenLinks = await getBrokenLinks(site.id);
      }
    }

    // Limit internal pages to scan (to avoid excessive processing)
    const maxPagesToScan = 50; // Per-batch limit
    final remainingPageLimit = AppConstants.freePlanPageLimit - startIndex;
    final actualPagesToScan = maxPagesToScan.clamp(0, remainingPageLimit);

    final endIndex = (startIndex + actualPagesToScan).clamp(
      0,
      allInternalPages.length,
    );
    final pagesToScan = allInternalPages.sublist(startIndex, endIndex);
    final scanCompleted =
        endIndex >= allInternalPages.length ||
        endIndex >= AppConstants.freePlanPageLimit;

    // Step 2: Extract links from each internal page
    final allFoundLinks = <Uri>{};
    final externalLinks = <Uri>{};
    final internalLinks = <Uri>{};
    final linkSourceMap = <String, String>{}; // link -> foundOn
    final visitedPages = <String>{};

    // Count total links found (including duplicates across pages)
    int totalInternalLinksCount = 0;
    int totalExternalLinksCount = 0;

    int pagesScanned = 0;
    for (final page in pagesToScan) {
      final pageUrl = page.toString();

      // Skip if already visited
      if (visitedPages.contains(pageUrl)) continue;
      visitedPages.add(pageUrl);

      // Report progress (cumulative)
      pagesScanned++;
      final cumulativePagesScanned = startIndex + pagesScanned;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      // Add delay to avoid server overload and firewall detection
      if (pagesScanned > 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Fetch and parse HTML
      final htmlContent = await _fetchHtmlContent(pageUrl);
      if (htmlContent == null) continue;

      // Extract all links from this page
      final links = _extractLinks(htmlContent, page);

      for (final link in links) {
        // Normalize the link to ensure consistent URL representation (remove fragments, trailing slashes, normalize case)
        final normalizedLink = _normalizeSitemapUrl(link);
        final linkUrl = normalizedLink.toString();
        allFoundLinks.add(normalizedLink);

        // Record where this link was found
        if (!linkSourceMap.containsKey(linkUrl)) {
          linkSourceMap[linkUrl] = pageUrl;
        }

        // Categorize: internal or external (use original base URL for comparison)
        if (_isSameDomain(normalizedLink, originalBaseUrl)) {
          // Internal link - mark for checking
          internalLinks.add(normalizedLink);
          totalInternalLinksCount++; // Count each occurrence
        } else {
          // External link - mark for checking
          externalLinks.add(normalizedLink);
          totalExternalLinksCount++; // Count each occurrence
        }
      }
    }

    // Step 3: Check internal links for broken pages
    final brokenLinks = <BrokenLink>[];
    final internalLinksList = internalLinks.toList();
    final totalInternalLinks = internalLinksList.length;

    // Calculate total links to check (for progress reporting)
    final externalLinksCount = checkExternalLinks ? externalLinks.length : 0;
    final totalAllLinks = totalInternalLinks + externalLinksCount;
    int checkedInternal = 0;

    // Report initial state if there are links to check
    if (totalAllLinks > 0) {
      onExternalLinksProgress?.call(0, totalAllLinks);
    }

    for (final link in internalLinksList) {
      final linkUrl = link.toString();

      // Add delay to avoid server overload
      if (checkedInternal > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final isBroken = await _checkLink(link);

      if (isBroken != null) {
        brokenLinks.add(
          BrokenLink(
            id: '', // Will be set by Firestore
            siteId: site.id,
            userId: _currentUserId!,
            timestamp: DateTime.now(),
            url: linkUrl,
            foundOn: linkSourceMap[linkUrl] ?? site.url,
            statusCode: isBroken.statusCode,
            error: isBroken.error,
            linkType: LinkType.internal,
          ),
        );
      }

      checkedInternal++;
      // Always report internal links progress
      if (totalAllLinks > 0) {
        onExternalLinksProgress?.call(checkedInternal, totalAllLinks);
      }
    }

    // Step 4: Check external links only if requested
    if (checkExternalLinks) {
      // Notify that external link checking is starting
      final cumulativePagesScanned = startIndex + pagesScanned;
      onProgress?.call(cumulativePagesScanned, totalPagesInSitemap);

      final externalLinksList = externalLinks.toList();
      int checkedExternal = 0;

      for (final link in externalLinksList) {
        final linkUrl = link.toString();

        // Add delay to avoid server overload
        if (checkedExternal > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final isBroken = await _checkLink(link);

        if (isBroken != null) {
          brokenLinks.add(
            BrokenLink(
              id: '', // Will be set by Firestore
              siteId: site.id,
              userId: _currentUserId!,
              timestamp: DateTime.now(),
              url: linkUrl,
              foundOn: linkSourceMap[linkUrl] ?? site.url,
              statusCode: isBroken.statusCode,
              error: isBroken.error,
              linkType: LinkType.external,
            ),
          );
        }

        checkedExternal++;
        // Report combined progress (internal + external)
        final totalChecked = checkedInternal + checkedExternal;
        onExternalLinksProgress?.call(totalChecked, totalAllLinks);
      }
    }

    // Step 5: Prepare broken links
    // If continuing, keep previous broken links and add new ones
    final allBrokenLinks =
        continueFromLastScan && previousBrokenLinks.isNotEmpty
        ? [...previousBrokenLinks, ...brokenLinks]
        : brokenLinks;

    // Step 6: Create and save result
    final endTime = DateTime.now();
    final newLastScannedPageIndex = scanCompleted
        ? 0
        : endIndex; // Reset to 0 if completed

    // Calculate cumulative statistics
    final previousTotalLinks = previousResult?.totalLinks ?? 0;
    final previousInternalLinks = previousResult?.internalLinks ?? 0;
    final previousExternalLinks = previousResult?.externalLinks ?? 0;

    // Total links = sum of internal and external link occurrences (including duplicates)
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
      checkedUrl: site.url, // Record the URL that was checked
      checkedSitemapUrl: site.sitemapUrl, // Record the sitemap URL used
      timestamp: DateTime.now(),
      totalLinks: cumulativeTotalLinks,
      brokenLinks: allBrokenLinks.length,
      internalLinks:
          cumulativeInternalLinks, // Total internal links found (cumulative, including duplicates)
      externalLinks:
          cumulativeExternalLinks, // Total external links found (cumulative, including duplicates)
      scanDuration: endTime.difference(startTime),
      pagesScanned: endIndex, // Total pages scanned so far
      totalPagesInSitemap: totalPagesInSitemap,
      scanCompleted: scanCompleted,
      newLastScannedPageIndex: newLastScannedPageIndex,
    );

    // Save to Firestore and get the document reference
    final docRef = await _resultsCollection(
      _currentUserId!,
    ).add(result.toFirestore());

    final resultId = docRef.id;

    // Save broken links as subcollection under this result
    await _saveBrokenLinks(resultId, allBrokenLinks);

    // Cleanup old link check results (keep only latest 10 per site)
    _cleanupOldResults(site.id).catchError((error) {
      // Log error but don't throw - cleanup failure shouldn't block the scan result
      _logger.e('Failed to cleanup old link check results', error: error);
    });

    // Return result with the Firestore document ID
    return LinkCheckResult(
      id: resultId,
      siteId: result.siteId,
      checkedUrl: result.checkedUrl,
      checkedSitemapUrl: result.checkedSitemapUrl,
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

  /// Cleanup old link check results for a site (keep only latest 10)
  Future<void> _cleanupOldResults(String siteId) async {
    if (_currentUserId == null) return;

    try {
      // Get results older than the 10th newest
      final querySnapshot = await _resultsCollection(_currentUserId!)
          .where('siteId', isEqualTo: siteId)
          .orderBy('timestamp', descending: true)
          .get();

      // If we have 10 or fewer results, no cleanup needed
      if (querySnapshot.docs.length <= 10) return;

      // Delete results beyond the 10th (including their broken links subcollections)
      final batch = _firestore.batch();
      for (int i = 10; i < querySnapshot.docs.length; i++) {
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
        'Cleaned up ${querySnapshot.docs.length - 10} old link check results for site $siteId',
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

      // Check if the path starts with any of the excluded paths
      for (final excludedPath in excludedPaths) {
        // Normalize the excluded path (ensure it starts with /)
        final normalizedExcludedPath = excludedPath.startsWith('/')
            ? excludedPath
            : '/$excludedPath';

        if (path.startsWith(normalizedExcludedPath)) {
          return false; // Exclude this URL
        }
      }

      return true; // Include this URL
    }).toList();
  }
}
