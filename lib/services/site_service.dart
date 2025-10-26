import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/site.dart';

class SiteService {
  static const String _collectionName = 'sites';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection reference for sites
  CollectionReference get _sitesCollection =>
      _firestore.collection(_collectionName);

  // Create a new site
  Future<String> createSite(Site site) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to create a site');
    }

    // Ensure the site belongs to the current user
    final siteData = site.copyWith(userId: _currentUserId!);

    try {
      final docRef = await _sitesCollection.add(siteData.toFirestore());
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

    return _sitesCollection
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Site.fromFirestore(doc)).toList();
        });
  }

  // Get a specific site by ID
  Future<Site?> getSite(String siteId) async {
    try {
      final doc = await _sitesCollection.doc(siteId).get();
      if (doc.exists) {
        final site = Site.fromFirestore(doc);
        // Verify ownership
        if (site.userId == _currentUserId) {
          return site;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get site: $e');
    }
  }

  // Update an existing site
  Future<void> updateSite(Site site) async {
    if (_currentUserId == null) {
      throw Exception('User must be authenticated to update a site');
    }

    // Verify ownership
    if (site.userId != _currentUserId) {
      throw Exception(
        'Unauthorized: Cannot update site belonging to another user',
      );
    }

    try {
      await _sitesCollection.doc(site.id).update(site.toFirestore());
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
      // First verify ownership
      final site = await getSite(siteId);
      if (site == null || site.userId != _currentUserId) {
        throw Exception('Unauthorized: Cannot delete site');
      }

      await _sitesCollection.doc(siteId).delete();
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

    return _sitesCollection
        .where('userId', isEqualTo: _currentUserId)
        .where('monitoringEnabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Site.fromFirestore(doc)).toList();
        });
  }

  // Check if URL already exists for current user
  Future<bool> urlExists(String url, {String? excludeSiteId}) async {
    if (_currentUserId == null) return false;

    try {
      final query = await _sitesCollection
          .where('userId', isEqualTo: _currentUserId)
          .where('url', isEqualTo: url)
          .get();

      if (excludeSiteId != null) {
        return query.docs.any((doc) => doc.id != excludeSiteId);
      }

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Validate URL format and accessibility
  Future<bool> validateUrl(String url) async {
    try {
      // Basic URL validation
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }

      // You could add HTTP head request here to check if URL is accessible
      // For now, just return basic validation result
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get site count for current user
  Future<int> getSiteCount() async {
    if (_currentUserId == null) return 0;

    try {
      final query = await _sitesCollection
          .where('userId', isEqualTo: _currentUserId)
          .get();
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
