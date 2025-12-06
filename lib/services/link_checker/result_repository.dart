import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../models/broken_link.dart';

/// Repository for managing link check results in Firestore
class LinkCheckResultRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;
  final String userId;
  final int historyLimit;

  LinkCheckResultRepository({
    required FirebaseFirestore firestore,
    required Logger logger,
    required this.userId,
    required this.historyLimit,
  }) : _firestore = firestore,
       _logger = logger;

  // Collection references
  CollectionReference get _resultsCollection =>
      _firestore.collection('users').doc(userId).collection('linkCheckResults');

  CollectionReference _brokenLinksCollection(String resultId) =>
      _resultsCollection.doc(resultId).collection('brokenLinks');

  /// Get broken links for a specific result
  Future<List<BrokenLink>> getBrokenLinks(String resultId) async {
    final snapshot = await _brokenLinksCollection(
      resultId,
    ).orderBy('timestamp', descending: true).get();

    return snapshot.docs.map((doc) => BrokenLink.fromFirestore(doc)).toList();
  }

  /// Delete all broken links for a specific result
  Future<void> deleteResultBrokenLinks(String resultId) async {
    final snapshot = await _brokenLinksCollection(resultId).get();

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

  /// Get check results history for a site
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 50,
  }) async {
    final snapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => LinkCheckResult.fromFirestore(doc))
        .toList();
  }

  /// Get all check results across all sites
  Future<List<LinkCheckResult>> getAllCheckResults({int limit = 50}) async {
    final snapshot = await _resultsCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => LinkCheckResult.fromFirestore(doc))
        .toList();
  }

  /// Delete all check results for a specific site
  Future<void> deleteAllCheckResults(String siteId) async {
    final snapshot = await _resultsCollection
        .where('siteId', isEqualTo: siteId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      // Delete broken links subcollection
      final brokenLinksSnapshot = await doc.reference
          .collection('brokenLinks')
          .get();
      for (final brokenLinkDoc in brokenLinksSnapshot.docs) {
        batch.delete(brokenLinkDoc.reference);
      }

      // Delete the result document
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Delete a specific link check result by document ID
  Future<void> deleteLinkCheckResult(String resultId) async {
    // Delete all broken links in the subcollection first
    await deleteResultBrokenLinks(resultId);

    // Delete the result document
    await _resultsCollection.doc(resultId).delete();
  }

  /// Save a link check result to Firestore
  Future<String> saveResult(LinkCheckResult result) async {
    final docRef = await _resultsCollection.add(result.toFirestore());
    return docRef.id;
  }

  /// Save broken links as subcollection
  Future<void> saveBrokenLinks(
    String resultId,
    List<BrokenLink> brokenLinks,
  ) async {
    if (brokenLinks.isEmpty) return;

    final batch = _firestore.batch();
    final collectionRef = _brokenLinksCollection(resultId);

    for (final link in brokenLinks) {
      final docRef = collectionRef.doc();
      batch.set(docRef, link.toFirestore());
    }

    await batch.commit();
  }

  /// Cleanup old link check results for a site (respects premium/free limits)
  Future<void> cleanupOldResults(String siteId) async {
    try {
      // Get all results for the site
      final querySnapshot = await _resultsCollection
          .where('siteId', isEqualTo: siteId)
          .orderBy('timestamp', descending: true)
          .get();

      // If we have fewer results than the limit, no cleanup needed
      if (querySnapshot.docs.length <= historyLimit) return;

      // Delete results beyond the limit (including their broken links subcollections)
      final batch = _firestore.batch();
      for (int i = historyLimit; i < querySnapshot.docs.length; i++) {
        final docRef = querySnapshot.docs[i].reference;

        // Delete broken links subcollection
        final brokenLinksSnapshot = await docRef
            .collection('brokenLinks')
            .get();
        for (final brokenLinkDoc in brokenLinksSnapshot.docs) {
          batch.delete(brokenLinkDoc.reference);
        }

        // Delete the result document itself
        batch.delete(docRef);
      }

      await batch.commit();
      _logger.i(
        'Cleaned up ${querySnapshot.docs.length - historyLimit} old link check results for site $siteId',
      );
    } catch (e) {
      _logger.e('Error during cleanup of old link check results', error: e);
      rethrow;
    }
  }
}
