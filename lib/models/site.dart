import 'package:cloud_firestore/cloud_firestore.dart';

class Site {
  final String id;
  final String userId;
  final String url;
  final String name;
  final bool monitoringEnabled;
  final int checkInterval; // minutes
  final DateTime createdAt;
  final DateTime? lastChecked;
  final String? sitemapUrl; // Sitemap URL for link checking (optional)
  final int
  lastScannedPageIndex; // Last scanned page index for progressive scanning

  Site({
    required this.id,
    required this.userId,
    required this.url,
    required this.name,
    this.monitoringEnabled = true,
    this.checkInterval = 60, // Default: 60 minutes
    required this.createdAt,
    this.lastChecked,
    this.sitemapUrl,
    this.lastScannedPageIndex = 0, // Default: 0 (start from beginning)
  });

  // Factory constructor to create Site from Firestore document
  factory Site.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Site(
      id: doc.id,
      userId: data['userId'] ?? '',
      url: data['url'] ?? '',
      name: data['name'] ?? '',
      monitoringEnabled: data['monitoringEnabled'] ?? true,
      checkInterval: data['checkInterval'] ?? 60,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastChecked: (data['lastChecked'] as Timestamp?)?.toDate(),
      sitemapUrl: data['sitemapUrl'],
      lastScannedPageIndex: (data['lastScannedPageIndex'] as int?) ?? 0,
    );
  }

  // Convert Site to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'url': url,
      'name': name,
      'monitoringEnabled': monitoringEnabled,
      'checkInterval': checkInterval,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastChecked': lastChecked != null
          ? Timestamp.fromDate(lastChecked!)
          : null,
      'sitemapUrl': sitemapUrl,
      'lastScannedPageIndex': lastScannedPageIndex,
    };
  }

  // Copy with method for updates
  Site copyWith({
    String? id,
    String? userId,
    String? url,
    String? name,
    bool? monitoringEnabled,
    int? checkInterval,
    DateTime? createdAt,
    DateTime? lastChecked,
    String? sitemapUrl,
    int? lastScannedPageIndex,
  }) {
    return Site(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      name: name ?? this.name,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      checkInterval: checkInterval ?? this.checkInterval,
      createdAt: createdAt ?? this.createdAt,
      lastChecked: lastChecked ?? this.lastChecked,
      sitemapUrl: sitemapUrl ?? this.sitemapUrl,
      lastScannedPageIndex: lastScannedPageIndex ?? this.lastScannedPageIndex,
    );
  }

  // Validation methods
  bool get isValidUrl {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  String get displayUrl {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  // Status helpers
  String get lastCheckedDisplay {
    if (lastChecked == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastChecked!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String get checkIntervalDisplay {
    if (checkInterval < 60) return '${checkInterval}m';
    final hours = checkInterval ~/ 60;
    final minutes = checkInterval % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  @override
  String toString() {
    return 'Site{id: $id, name: $name, url: $url, monitoringEnabled: $monitoringEnabled}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Site && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
