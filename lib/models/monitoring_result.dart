import 'package:cloud_firestore/cloud_firestore.dart';

/// Monitoring result model for site health checks
class MonitoringResult {
  final String id;
  final String siteId;
  final String userId;
  final DateTime timestamp;
  final int statusCode;
  final int responseTime; // milliseconds
  final bool isUp;
  final String? error;
  final int?
  sitemapStatusCode; // HTTP status from sitemap check (200=OK, 404=Not Found, 0=Network Error)

  MonitoringResult({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.timestamp,
    required this.statusCode,
    required this.responseTime,
    required this.isUp,
    this.error,
    this.sitemapStatusCode,
  });

  /// Create MonitoringResult from Firestore document
  factory MonitoringResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MonitoringResult(
      id: doc.id,
      siteId: data['siteId'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      statusCode: data['statusCode'] ?? 0,
      responseTime: data['responseTime'] ?? 0,
      isUp: data['isUp'] ?? false,
      error: data['error'],
      sitemapStatusCode: data['sitemapStatusCode'] as int?,
    );
  }

  /// Convert MonitoringResult to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'siteId': siteId,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'statusCode': statusCode,
      'responseTime': responseTime,
      'isUp': isUp,
      'error': error,
      'sitemapStatusCode': sitemapStatusCode,
    };
  }

  /// Create a copy with modified fields
  MonitoringResult copyWith({
    String? id,
    String? siteId,
    String? userId,
    DateTime? timestamp,
    int? statusCode,
    int? responseTime,
    bool? isUp,
    String? error,
    int? sitemapStatusCode,
  }) {
    return MonitoringResult(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      statusCode: statusCode ?? this.statusCode,
      responseTime: responseTime ?? this.responseTime,
      isUp: isUp ?? this.isUp,
      error: error ?? this.error,
      sitemapStatusCode: sitemapStatusCode ?? this.sitemapStatusCode,
    );
  }

  /// Check if the status code indicates success
  bool get isSuccess => statusCode >= 200 && statusCode < 400;

  /// Get status code category
  String get statusCategory {
    if (statusCode == 0) return 'Error';
    if (statusCode >= 200 && statusCode < 300) return 'Success';
    if (statusCode >= 300 && statusCode < 400) return 'Redirect';
    if (statusCode >= 400 && statusCode < 500) return 'Client Error';
    if (statusCode >= 500) return 'Server Error';
    return 'Unknown';
  }

  /// Format response time for display
  String get formattedResponseTime {
    if (responseTime < 1000) {
      return '${responseTime}ms';
    }
    return '${(responseTime / 1000).toStringAsFixed(2)}s';
  }

  @override
  String toString() {
    return 'MonitoringResult(id: $id, siteId: $siteId, timestamp: $timestamp, '
        'statusCode: $statusCode, responseTime: $responseTime, isUp: $isUp)';
  }
}
