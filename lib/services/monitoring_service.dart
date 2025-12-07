import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../utils/url_helper.dart';

/// Service for monitoring website health
class MonitoringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  // History limit for cleanup (can be set based on premium status)
  int _historyLimit = AppConstants.freePlanHistoryLimit;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Set history limit based on premium status
  void setHistoryLimit(bool isPremium) {
    _historyLimit = isPremium
        ? AppConstants.premiumHistoryLimit
        : AppConstants.freePlanHistoryLimit;
  }

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
    int? sitemapStatusCode;

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

    // Check sitemap if site has sitemapUrl and base URL is accessible
    if (site.sitemapUrl != null && site.sitemapUrl!.isNotEmpty && isUp) {
      try {
        // Build full sitemap URL
        final baseUri = Uri.parse(
          UrlHelper.convertLocalhostForPlatform(site.url),
        );
        final baseUrl =
            '${baseUri.scheme}://${baseUri.host}${baseUri.port != 80 && baseUri.port != 443 ? ':${baseUri.port}' : ''}';

        // Normalize sitemap URL path
        String sitemapUrlPath = site.sitemapUrl!;
        if (!sitemapUrlPath.startsWith('/')) {
          sitemapUrlPath = '/$sitemapUrlPath';
        }

        final fullSitemapUrl = '$baseUrl$sitemapUrlPath';
        final convertedSitemapUrl = UrlHelper.convertLocalhostForPlatform(
          fullSitemapUrl,
        );

        // Perform HEAD request to check sitemap availability
        final sitemapResponse = await http
            .head(Uri.parse(convertedSitemapUrl))
            .timeout(const Duration(seconds: 5));

        sitemapStatusCode = sitemapResponse.statusCode;
      } catch (e) {
        // Network error checking sitemap, set status code to 0
        sitemapStatusCode = 0;
        _logger.d('Sitemap check failed for ${site.id}: $e');
      }
    } else if (site.sitemapUrl == null || site.sitemapUrl!.isEmpty) {
      // No sitemap URL configured
      sitemapStatusCode = null;
    } else {
      // Base URL is not accessible, sitemap check cannot be performed
      sitemapStatusCode = null;
    }

    final endTime = DateTime.now();
    final responseTime = endTime.difference(startTime).inMilliseconds;

    // Create monitoring result with sitemap status
    final result = MonitoringResult(
      id: '', // Will be set by Firestore
      siteId: site.id,
      userId: _currentUserId!,
      timestamp: DateTime.now(),
      statusCode: statusCode,
      responseTime: responseTime,
      isUp: isUp,
      error: error,
      sitemapStatusCode: sitemapStatusCode,
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

    // Cleanup old monitoring results (keep only latest 10 per site)
    _cleanupOldResults(site.id).catchError((error) {
      _logger.e('Failed to cleanup old monitoring results', error: error);
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

  /// Cleanup old monitoring results for a site (respects premium/free limits)
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

      // Delete results beyond the limit
      final batch = _firestore.batch();
      for (int i = _historyLimit; i < querySnapshot.docs.length; i++) {
        batch.delete(querySnapshot.docs[i].reference);
      }

      await batch.commit();
      _logger.i(
        'Cleaned up ${querySnapshot.docs.length - _historyLimit} old monitoring results for site $siteId',
      );
    } catch (e) {
      _logger.e('Error during cleanup of old monitoring results', error: e);
      rethrow;
    }
  }
}
