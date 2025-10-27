import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/broken_link.dart';
import '../models/site.dart';

/// Service for checking broken links on websites
class LinkCheckerService {
  static const String _collectionName = 'brokenLinks';
  static const String _resultsCollectionName = 'linkCheckResults';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference get _brokenLinksCollection =>
      _firestore.collection(_collectionName);
  CollectionReference get _resultsCollection =>
      _firestore.collection(_resultsCollectionName);

  /// Check all links on a site
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = false,
    void Function(int checked, int total)? onProgress,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check links');
    }

    final startTime = DateTime.now();
    final baseUrl = Uri.parse(site.url);

    // Step 1: Fetch HTML content
    final htmlContent = await _fetchHtmlContent(site.url);
    if (htmlContent == null) {
      throw Exception('Failed to fetch site content');
    }

    // Step 2: Extract links
    final links = _extractLinks(htmlContent, baseUrl);

    // Step 3: Categorize links
    final internalLinks = <Uri>[];
    final externalLinks = <Uri>[];

    for (final link in links) {
      if (_isSameDomain(link, baseUrl)) {
        internalLinks.add(link);
      } else {
        externalLinks.add(link);
      }
    }

    // Step 4: Check links
    final brokenLinks = <BrokenLink>[];
    final linksToCheck = [
      ...internalLinks,
      if (checkExternalLinks) ...externalLinks,
    ];

    int checked = 0;
    for (final link in linksToCheck) {
      final isBroken = await _checkLink(link);
      if (isBroken != null) {
        brokenLinks.add(
          BrokenLink(
            id: '', // Will be set by Firestore
            siteId: site.id,
            userId: _currentUserId!,
            timestamp: DateTime.now(),
            url: link.toString(),
            foundOn: site.url,
            statusCode: isBroken.statusCode,
            error: isBroken.error,
            linkType: _isSameDomain(link, baseUrl)
                ? LinkType.internal
                : LinkType.external,
          ),
        );
      }

      checked++;
      onProgress?.call(checked, linksToCheck.length);
    }

    // Step 5: Save broken links to Firestore
    await _saveBrokenLinks(brokenLinks);

    // Step 6: Create and save result
    final endTime = DateTime.now();
    final result = LinkCheckResult(
      siteId: site.id,
      timestamp: DateTime.now(),
      totalLinks: links.length,
      brokenLinks: brokenLinks.length,
      internalLinks: internalLinks.length,
      externalLinks: externalLinks.length,
      scanDuration: endTime.difference(startTime),
    );

    await _resultsCollection.add(result.toFirestore());

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
    if (brokenLinks.isEmpty) return;

    final batch = _firestore.batch();
    for (final link in brokenLinks) {
      final docRef = _brokenLinksCollection.doc();
      batch.set(docRef, link.toFirestore());
    }

    await batch.commit();
  }

  /// Get broken links for a site
  Stream<List<BrokenLink>> getSiteBrokenLinks(
    String siteId, {
    int limit = 100,
  }) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _brokenLinksCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BrokenLink.fromFirestore(doc))
              .toList();
        });
  }

  /// Delete all broken links for a site
  Future<void> deleteSiteBrokenLinks(String siteId) async {
    if (_currentUserId == null) return;

    final snapshot = await _brokenLinksCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Get latest check result for a site
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) async {
    final snapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return LinkCheckResult.fromFirestore(snapshot.docs.first);
  }
}
