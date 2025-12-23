import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/site.dart';
import '../utils/validation_utils.dart';

abstract class SiteUpdater {
  Future<void> updateSite(Site site);
}

class SiteService implements SiteUpdater {
  static const String _firebaseAppName = 'sitecat-current';
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  SiteService({FirebaseFirestore? firestore, FirebaseAuth? auth}) {
    final app = Firebase.app(_firebaseAppName);
    _firestore = firestore ?? FirebaseFirestore.instanceFor(app: app);
    _auth = auth ?? FirebaseAuth.instanceFor(app: app);
  }

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection reference for sites (hierarchical structure)
  CollectionReference _sitesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('sites');

  // Create a new site
  Future<String> createSite(Site site) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to create a site');
    }

    // Ensure the site belongs to the current user
    final siteData = site.copyWith(userId: _currentUserId!);

    try {
      final docRef = await _sitesCollection(
        _currentUserId!,
      ).add(siteData.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create site: $e');
    }
  }

  // Get all sites for the current user
  Stream<List<Site>> getUserSites() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _sitesCollection(
      _currentUserId!,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Site.fromFirestore(doc)).toList();
    });
  }

  // Get a specific site by ID
  Future<Site?> getSite(String siteId) async {
    if (_currentUserId == null) {
      return null;
    }

    try {
      final doc = await _sitesCollection(_currentUserId!).doc(siteId).get();
      if (doc.exists) {
        return Site.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get site: $e');
    }
  }

  // Update an existing site
  @override
  Future<void> updateSite(Site site) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to update a site');
    }

    // Some legacy documents may miss userId; align them to the current user
    final currentUserId = _currentUserId!;
    final siteToUpdate = site.userId.isEmpty
        ? site.copyWith(userId: currentUserId)
        : site;

    // Verify ownership
    if (siteToUpdate.userId != currentUserId) {
      throw Exception(
        'Unauthorized: Cannot update site belonging to another user',
      );
    }

    try {
      await _sitesCollection(
        currentUserId,
      ).doc(siteToUpdate.id).update(siteToUpdate.toFirestore());
    } catch (e) {
      throw Exception('Failed to update site: $e');
    }
  }

  // Delete a site
  Future<void> deleteSite(String siteId) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to delete a site');
    }

    try {
      await _sitesCollection(_currentUserId!).doc(siteId).delete();
    } catch (e) {
      throw Exception('Failed to delete site: $e');
    }
  }

  // Toggle monitoring for a site
  Future<void> toggleMonitoring(String siteId, bool enabled) async {
    final site = await getSite(siteId);
    if (site == null) {
      throw Exception('Site not found');
    }

    final updatedSite = site.copyWith(monitoringEnabled: enabled);
    await updateSite(updatedSite);
  }

  // Update last checked timestamp
  Future<void> updateLastChecked(String siteId, DateTime timestamp) async {
    final site = await getSite(siteId);
    if (site == null) {
      throw Exception('Site not found');
    }

    final updatedSite = site.copyWith(lastChecked: timestamp);
    await updateSite(updatedSite);
  }

  // Get sites that need monitoring (enabled sites)
  Stream<List<Site>> getMonitoringSites() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _sitesCollection(
      _currentUserId!,
    ).where('monitoringEnabled', isEqualTo: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Site.fromFirestore(doc)).toList();
    });
  }

  // Check if URL already exists for current user
  Future<bool> urlExists(String url, {String? excludeSiteId}) async {
    if (_currentUserId == null) return false;

    try {
      final query = await _sitesCollection(
        _currentUserId!,
      ).where('url', isEqualTo: url).get();

      if (excludeSiteId != null) {
        return query.docs.any((doc) => doc.id != excludeSiteId);
      }

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Validate URL format and accessibility.
  ///
  /// Currently checks URL format via [ValidationUtils.isValidUrl].
  /// Kept as async `Future&lt;bool&gt;` to support future HTTP head requests
  /// that check accessibility without blocking synchronous validation.
  /// This allows both fast format validation and optional deeper checks.
  Future<bool> validateUrl(String url) async {
    return ValidationUtils.isValidUrl(url);
  }

  // Get site count for current user
  Future<int> getSiteCount() async {
    if (_currentUserId == null) return 0;

    try {
      final query = await _sitesCollection(_currentUserId!).get();
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Search sites by name or URL
  Stream<List<Site>> searchSites(String searchTerm) {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    // Note: Firestore doesn't support full-text search natively
    // This is a basic implementation that filters on the client side
    return getUserSites().map((sites) {
      if (searchTerm.isEmpty) return sites;

      final term = searchTerm.toLowerCase();
      return sites.where((site) {
        return site.name.toLowerCase().contains(term) ||
            site.url.toLowerCase().contains(term);
      }).toList();
    });
  }
}
