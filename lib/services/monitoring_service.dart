import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/monitoring_result.dart';
import '../models/site.dart';

/// Service for monitoring website health
class MonitoringService {
  static const String _collectionName = 'monitoringResults';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection reference for monitoring results
  CollectionReference get _resultsCollection =>
      _firestore.collection(_collectionName);

  /// Perform a health check on a site
  Future<MonitoringResult> checkSite(Site site) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to check sites');
    }

    final startTime = DateTime.now();
    int statusCode = 0;
    bool isUp = false;
    String? error;

    try {
      // Perform HTTP request
      final response = await http
          .get(Uri.parse(site.url))
          .timeout(const Duration(seconds: 30));

      statusCode = response.statusCode;
      isUp = statusCode >= 200 && statusCode < 400;
    } on http.ClientException catch (e) {
      error = 'Network error: ${e.message}';
    } on FormatException catch (e) {
      error = 'Invalid URL format: ${e.message}';
    } catch (e) {
      error = 'Error: $e';
    }

    final endTime = DateTime.now();
    final responseTime = endTime.difference(startTime).inMilliseconds;

    // Create monitoring result
    final result = MonitoringResult(
      id: '', // Will be set by Firestore
      siteId: site.id,
      userId: _currentUserId!,
      timestamp: DateTime.now(),
      statusCode: statusCode,
      responseTime: responseTime,
      isUp: isUp,
      error: error,
    );

    // Save to Firestore
    final docRef = await _resultsCollection.add(result.toFirestore());

    // Update site's lastChecked timestamp
    await _firestore.collection('sites').doc(site.id).update({
      'lastChecked': Timestamp.now(),
    });

    return result.copyWith(id: docRef.id);
  }

  /// Get monitoring results for a specific site
  Stream<List<MonitoringResult>> getSiteResults(
    String siteId, {
    int limit = 50,
  }) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MonitoringResult.fromFirestore(doc))
              .toList();
        });
  }

  /// Get the latest result for a site
  Future<MonitoringResult?> getLatestResult(String siteId) async {
    if (_currentUserId == null) {
      return null;
    }

    final querySnapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return MonitoringResult.fromFirestore(querySnapshot.docs.first);
  }

  /// Calculate uptime percentage for a site
  Future<double> calculateUptime(
    String siteId, {
    Duration period = const Duration(days: 7),
  }) async {
    if (_currentUserId == null) {
      return 0.0;
    }

    final startDate = DateTime.now().subtract(period);

    final querySnapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 0.0;
    }

    final totalChecks = querySnapshot.docs.length;
    final upChecks = querySnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isUp'] == true)
        .length;

    return (upChecks / totalChecks) * 100;
  }

  /// Calculate average response time for a site
  Future<int> calculateAverageResponseTime(
    String siteId, {
    Duration period = const Duration(days: 7),
  }) async {
    if (_currentUserId == null) {
      return 0;
    }

    final startDate = DateTime.now().subtract(period);

    final querySnapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(startDate))
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 0;
    }

    final totalResponseTime = querySnapshot.docs.fold<int>(
      0,
      (total, doc) =>
          total +
          ((doc.data() as Map<String, dynamic>)['responseTime'] as int? ?? 0),
    );

    return totalResponseTime ~/ querySnapshot.docs.length;
  }

  /// Delete monitoring results for a site
  Future<void> deleteSiteResults(String siteId) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated');
    }

    final querySnapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .where('userId', isEqualTo: _currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
