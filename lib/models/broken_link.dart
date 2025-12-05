import 'package:cloud_firestore/cloud_firestore.dart';

/// Broken link model for link checking results
class BrokenLink {
  final String id;
  final String siteId;
  final String userId;
  final DateTime timestamp;
  final String url; // The broken link URL
  final String foundOn; // The page where the link was found
  final int statusCode;
  final String? error;
  final LinkType linkType; // Internal or External

  BrokenLink({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.timestamp,
    required this.url,
    required this.foundOn,
    required this.statusCode,
    this.error,
    required this.linkType,
  });

  /// Create BrokenLink from Firestore document
  factory BrokenLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BrokenLink(
      id: doc.id,
      siteId: data['siteId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      url: data['url'] ?? '',
      foundOn: data['foundOn'] ?? '',
      statusCode: data['statusCode'] ?? 0,
      error: data['error'],
      linkType: LinkType.values.firstWhere(
        (type) => type.name == data['linkType'],
        orElse: () => LinkType.internal,
      ),
    );
  }

  /// Convert BrokenLink to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'siteId': siteId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'url': url,
      'foundOn': foundOn,
      'statusCode': statusCode,
      'error': error,
      'linkType': linkType.name,
    };
  }

  /// Create a copy with modified fields
  BrokenLink copyWith({
    String? id,
    String? siteId,
    String? userId,
    DateTime? timestamp,
    String? url,
    String? foundOn,
    int? statusCode,
    String? error,
    LinkType? linkType,
  }) {
    return BrokenLink(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      url: url ?? this.url,
      foundOn: foundOn ?? this.foundOn,
      statusCode: statusCode ?? this.statusCode,
      error: error ?? this.error,
      linkType: linkType ?? this.linkType,
    );
  }

  /// Get status category
  String get statusCategory {
    if (statusCode == 0) return 'Error';
    if (statusCode == 404) return 'Not Found';
    if (statusCode >= 400 && statusCode < 500) return 'Client Error';
    if (statusCode >= 500) return 'Server Error';
    return 'Unknown';
  }

  @override
  String toString() {
    return 'BrokenLink(id: $id, url: $url, foundOn: $foundOn, statusCode: $statusCode)';
  }
}

/// Link type enumeration
enum LinkType {
  internal, // Link to same domain
  external, // Link to different domain
}

/// Link check scan result
class LinkCheckResult {
  final String?
  id; // Firestore document ID (optional, only available after save)
  final String siteId;
  final String checkedUrl; // URL that was checked (to detect mismatches)
  final String? checkedSitemapUrl; // Sitemap URL that was used for this scan
  final int?
  sitemapStatusCode; // HTTP status code from sitemap HEAD request (200=OK, 404=Not Found, 0=Network Error, null=No sitemap or not checked)
  final DateTime timestamp;
  final int totalLinks;
  final int brokenLinks;
  final int internalLinks;
  final int externalLinks;
  final Duration scanDuration;
  final int pagesScanned; // Total number of pages scanned so far
  final int totalPagesInSitemap; // Total pages found in sitemap
  final bool scanCompleted; // Whether all pages were scanned
  final int newLastScannedPageIndex; // Index to continue from next time

  LinkCheckResult({
    this.id,
    required this.siteId,
    required this.checkedUrl,
    this.checkedSitemapUrl,
    this.sitemapStatusCode,
    required this.timestamp,
    required this.totalLinks,
    required this.brokenLinks,
    required this.internalLinks,
    required this.externalLinks,
    required this.scanDuration,
    required this.pagesScanned,
    required this.totalPagesInSitemap,
    required this.scanCompleted,
    required this.newLastScannedPageIndex,
  });

  /// Create LinkCheckResult from Firestore document
  factory LinkCheckResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LinkCheckResult(
      id: doc.id,
      siteId: data['siteId'] ?? '',
      checkedUrl: data['checkedUrl'] ?? '', // URL that was checked
      checkedSitemapUrl: data['checkedSitemapUrl'], // Sitemap URL used
      sitemapStatusCode: data['sitemapStatusCode'] as int?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      totalLinks: data['totalLinks'] ?? 0,
      brokenLinks: data['brokenLinks'] ?? 0,
      internalLinks: data['internalLinks'] ?? 0,
      externalLinks: data['externalLinks'] ?? 0,
      scanDuration: Duration(milliseconds: data['scanDuration'] ?? 0),
      pagesScanned: (data['pagesScanned'] as int?) ?? 0,
      totalPagesInSitemap: (data['totalPagesInSitemap'] as int?) ?? 0,
      scanCompleted: (data['scanCompleted'] as bool?) ?? false,
      newLastScannedPageIndex: (data['newLastScannedPageIndex'] as int?) ?? 0,
    );
  }

  /// Convert LinkCheckResult to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'siteId': siteId,
      'checkedUrl': checkedUrl,
      'checkedSitemapUrl': checkedSitemapUrl,
      'sitemapStatusCode': sitemapStatusCode,
      'timestamp': Timestamp.fromDate(timestamp),
      'totalLinks': totalLinks,
      'brokenLinks': brokenLinks,
      'internalLinks': internalLinks,
      'externalLinks': externalLinks,
      'scanDuration': scanDuration.inMilliseconds,
      'pagesScanned': pagesScanned,
      'totalPagesInSitemap': totalPagesInSitemap,
      'scanCompleted': scanCompleted,
      'newLastScannedPageIndex': newLastScannedPageIndex,
    };
  }
}
