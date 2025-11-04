import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../utils/url_helper.dart';

/// Service for monitoring website health
class MonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection reference for monitoring results (hierarchical structure)
  CollectionReference _resultsCollection(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('monitoringResults');

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
      // Convert localhost to platform-specific address (10.0.2.2 for Android emulator)
      final targetUrl = UrlHelper.convertLocalhostForPlatform(site.url);

      // Perform HTTP request with 10-second timeout to reduce load on target sites
      final response = await http
          .get(Uri.parse(targetUrl))
          .timeout(const Duration(seconds: 10));

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

    // Generate document reference with auto-generated ID
    final docRef = _resultsCollection(_currentUserId!).doc();

    // Save to Firestore asynchronously without waiting
    // Firestore handles offline persistence automatically
    docRef.set(result.toFirestore()).catchError((error) {
      _logger.e('Firestore set() failed', error: error);
    });

    // Update site's lastChecked timestamp asynchronously
    _firestore
        .collection('users')
        .doc(_currentUserId!)
        .collection('sites')
        .doc(site.id)
        .update({'lastChecked': Timestamp.now()})
        .catchError((error) {
          _logger.e('Firestore update() failed', error: error);
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

    return _resultsCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
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

    final querySnapshot = await _resultsCollection(_currentUserId!)
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return MonitoringResult.fromFirestore(querySnapshot.docs.first);
  }

  /// Delete monitoring results for a site
  Future<void> deleteSiteResults(String siteId) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated');
    }

    final querySnapshot = await _resultsCollection(
      _currentUserId!,
    ).where('siteId', isEqualTo: siteId).get();

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Delete a single monitoring result
  Future<void> deleteMonitoringResult(String siteId, String resultId) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated');
    }

    await _resultsCollection(_currentUserId!).doc(resultId).delete();
  }
}
