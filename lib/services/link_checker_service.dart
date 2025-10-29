import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;
import '../models/broken_link.dart';
import '../models/site.dart';

/// Service for checking broken links on websites
class LinkCheckerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references (hierarchical structure)
  CollectionReference _brokenLinksCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('brokenLinks');
  CollectionReference _resultsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('linkCheckResults');

  /// Check all links on a site
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = true,
    void Function(int checked, int total)? onProgress,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check links');
    }

    final startTime = DateTime.now();
    final baseUrl = Uri.parse(site.url);

    // Step 1: Get internal pages from sitemap (these are our pages to scan)
    List<Uri> allInternalPages = [];

    if (site.sitemapUrl != null && site.sitemapUrl!.isNotEmpty) {
      try {
        allInternalPages = await _fetchSitemapUrls(site.sitemapUrl!);
      } catch (e) {
        // Sitemap fetch failed, fall back to checking only the top page
        allInternalPages = [baseUrl];
      }
    } else {
      // No sitemap provided, check only the top page
      allInternalPages = [baseUrl];
    }

    final totalPagesInSitemap = allInternalPages.length;

    // Limit internal pages to scan (to avoid excessive processing)
    const maxPagesToScan = 50;
    final pagesToScan = allInternalPages.length > maxPagesToScan
        ? allInternalPages.take(maxPagesToScan).toList()
        : allInternalPages;
    final scanCompleted = pagesToScan.length == allInternalPages.length;

    // Step 2: Extract links from each internal page
    final allFoundLinks = <Uri>{};
    final externalLinks = <Uri>{};
    final linkSourceMap = <String, String>{}; // link -> foundOn
    final visitedPages = <String>{};

    int pagesScanned = 0;
    for (final page in pagesToScan) {
      final pageUrl = page.toString();

      // Skip if already visited
      if (visitedPages.contains(pageUrl)) continue;
      visitedPages.add(pageUrl);

      // Report progress
      pagesScanned++;
      onProgress?.call(pagesScanned, pagesToScan.length * 2);

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
        final linkUrl = link.toString();
        allFoundLinks.add(link);

        // Record where this link was found
        if (!linkSourceMap.containsKey(linkUrl)) {
          linkSourceMap[linkUrl] = pageUrl;
        }

        // Categorize: internal or external
        if (_isSameDomain(link, baseUrl)) {
          // Internal link (no need to check, assume OK if in sitemap)
        } else {
          // External link - mark for checking
          externalLinks.add(link);
        }
      }
    }

    // Step 3: Check external links only (HEAD request)
    final brokenLinks = <BrokenLink>[];

    if (checkExternalLinks) {
      final externalLinksList = externalLinks.toList();
      int checkedExternal = 0;

      for (final link in externalLinksList) {
        final linkUrl = link.toString();

        // Report progress
        checkedExternal++;
        onProgress?.call(
          pagesScanned + checkedExternal,
          pagesToScan.length + externalLinksList.length,
        );

        // Add delay to avoid server overload
        if (checkedExternal > 1) {
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
      }
    }

    // Step 4: Save broken links to Firestore
    await _saveBrokenLinks(brokenLinks);

    // Step 5: Create and save result
    final endTime = DateTime.now();
    final result = LinkCheckResult(
      siteId: site.id,
      timestamp: DateTime.now(),
      totalLinks: allFoundLinks.length,
      brokenLinks: brokenLinks.length,
      internalLinks: pagesToScan.length,
      externalLinks: externalLinks.length,
      scanDuration: endTime.difference(startTime),
      pagesScanned: pagesScanned,
      totalPagesInSitemap: totalPagesInSitemap,
      scanCompleted: scanCompleted,
    );

    await _resultsCollection(_currentUserId!).add(result.toFirestore());

    return result;
  }

  /// Fetch HTML content from URL
  Future<String?> _fetchHtmlContent(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
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
      final response = await http
          .get(Uri.parse(sitemapUrl))
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
                // Recursively fetch URLs from child sitemap
                final childUrls = await _fetchSitemapUrlsFromSingleSitemap(
                  childSitemapUrl,
                );
                allUrls.addAll(childUrls);

                // Limit total URLs to avoid excessive processing
                if (allUrls.length >= 100) {
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
        // This is a regular sitemap - extract URLs directly
        return _fetchSitemapUrlsFromSingleSitemap(sitemapUrl);
      }
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
  }

  /// Fetch URLs from a single sitemap (non-index)
  Future<List<Uri>> _fetchSitemapUrlsFromSingleSitemap(
    String sitemapUrl,
  ) async {
    try {
      final response = await http
          .get(Uri.parse(sitemapUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sitemap: ${response.statusCode}');
      }

      // Parse XML
      final document = xml.XmlDocument.parse(response.body);

      // Find all <loc> elements under <url> (not <sitemap>)
      final urlElements = document.findAllElements('url');

      final urls = <Uri>[];
      for (final urlElement in urlElements) {
        final locElement = urlElement.findElements('loc').firstOrNull;
        if (locElement != null) {
          final urlString = locElement.innerText.trim();
          if (urlString.isNotEmpty) {
            try {
              final uri = Uri.parse(urlString);
              if (uri.scheme == 'http' || uri.scheme == 'https') {
                urls.add(uri);
              }
            } catch (e) {
              // Invalid URL, skip
            }
          }
        }
      }

      return urls;
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
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
          links.add(uri);
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
      // Use HEAD request for efficiency
      final response = await http.head(url).timeout(const Duration(seconds: 5));

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
    return url1.host == url2.host;
  }

  /// Save broken links to Firestore
  Future<void> _saveBrokenLinks(List<BrokenLink> brokenLinks) async {
    if (brokenLinks.isEmpty || _currentUserId == null) return;

    final batch = _firestore.batch();
    for (final link in brokenLinks) {
      final docRef = _brokenLinksCollection(_currentUserId!).doc();
      batch.set(docRef, link.toFirestore());
    }

    await batch.commit();
  }

  /// Get broken links for a site (Stream)
  Stream<List<BrokenLink>> getSiteBrokenLinks(
    String siteId, {
    int limit = 100,
  }) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _brokenLinksCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BrokenLink.fromFirestore(doc))
              .toList();
        });
  }

  /// Get broken links for a site (Future)
  Future<List<BrokenLink>> getBrokenLinks(
    String siteId, {
    int limit = 100,
  }) async {
    if (_currentUserId == null) {
      return [];
    }

    final snapshot = await _brokenLinksCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => BrokenLink.fromFirestore(doc)).toList();
  }

  /// Delete all broken links for a site
  Future<void> deleteSiteBrokenLinks(String siteId) async {
    if (_currentUserId == null) return;

    final snapshot = await _brokenLinksCollection(
      _currentUserId!,
    ).where('siteId', isEqualTo: siteId).get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Clear broken links for a site (alias for deleteSiteBrokenLinks)
  Future<void> clearBrokenLinks(String siteId) async {
    return deleteSiteBrokenLinks(siteId);
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
}
