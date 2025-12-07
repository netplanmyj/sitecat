import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import 'result_repository.dart';

/// Builds and saves scan results
class ResultBuilder {
  final FirebaseFirestore _firestore;
  final Logger _logger;
  final int _historyLimit;

  ResultBuilder({
    required FirebaseFirestore firestore,
    required Logger logger,
    required int historyLimit,
  }) : _firestore = firestore,
       _logger = logger,
       _historyLimit = historyLimit;

  /// Merge broken links with previous scan results
  List<BrokenLink> mergeBrokenLinks({
    required List<BrokenLink> newBrokenLinks,
    required List<BrokenLink> previousBrokenLinks,
    required bool continueFromLastScan,
  }) {
    if (continueFromLastScan && previousBrokenLinks.isNotEmpty) {
      return [...previousBrokenLinks, ...newBrokenLinks];
    }
    return newBrokenLinks;
  }

  /// Create and save scan result to Firestore
  Future<LinkCheckResult> createAndSaveResult({
    required String userId,
    required Site site,
    required int? sitemapStatusCode,
    required int pagesScannedCount,
    required bool scanCompleted,
    required int resumeFromIndex,
    required int totalPagesInSitemap,
    required int totalInternalLinksCount,
    required int totalExternalLinksCount,
    required List<BrokenLink> allBrokenLinks,
    required LinkCheckResult? previousResult,
    required bool continueFromLastScan,
    required DateTime startTime,
    required int startIndex,
  }) async {
    final endTime = DateTime.now();
    final newLastScannedPageIndex = scanCompleted ? 0 : resumeFromIndex;

    // Calculate cumulative statistics
    final previousTotalLinks = previousResult?.totalLinks ?? 0;
    final previousInternalLinks = previousResult?.internalLinks ?? 0;
    final previousExternalLinks = previousResult?.externalLinks ?? 0;

    final totalLinksCount = totalInternalLinksCount + totalExternalLinksCount;
    final cumulativeTotalLinks = continueFromLastScan && previousResult != null
        ? previousTotalLinks + totalLinksCount
        : totalLinksCount;
    final cumulativeInternalLinks =
        continueFromLastScan && previousResult != null
        ? previousInternalLinks + totalInternalLinksCount
        : totalInternalLinksCount;
    final cumulativeExternalLinks =
        continueFromLastScan && previousResult != null
        ? previousExternalLinks + totalExternalLinksCount
        : totalExternalLinksCount;

    // Compute batch range (1-based for UI display)
    final batchStart = startIndex + 1;
    final batchEnd = pagesScannedCount;
    final pagesCompleted = pagesScannedCount;

    final result = LinkCheckResult(
      siteId: site.id,
      checkedUrl: site.url,
      checkedSitemapUrl: site.sitemapUrl,
      sitemapStatusCode: sitemapStatusCode,
      timestamp: DateTime.now(),
      totalLinks: cumulativeTotalLinks,
      brokenLinks: allBrokenLinks.length,
      internalLinks: cumulativeInternalLinks,
      externalLinks: cumulativeExternalLinks,
      scanDuration: endTime.difference(startTime),
      pagesScanned: pagesScannedCount,
      totalPagesInSitemap: totalPagesInSitemap,
      scanCompleted: scanCompleted,
      newLastScannedPageIndex: newLastScannedPageIndex,
      pagesCompleted: pagesCompleted,
      currentBatchStart: batchStart,
      currentBatchEnd: batchEnd,
    );

    // Create repository instance for this operation
    final repository = LinkCheckResultRepository(
      firestore: _firestore,
      userId: userId,
      logger: _logger,
      historyLimit: _historyLimit,
    );

    // Save to Firestore
    final resultId = await repository.saveResult(result);

    // Save broken links as subcollection
    await repository.saveBrokenLinks(resultId, allBrokenLinks);

    // Cleanup old results (async, non-blocking)
    repository.cleanupOldResults(site.id).catchError((error) {
      _logger.e('Failed to cleanup old link check results', error: error);
    });

    // Return result with Firestore document ID
    return LinkCheckResult(
      id: resultId,
      siteId: result.siteId,
      checkedUrl: result.checkedUrl,
      checkedSitemapUrl: result.checkedSitemapUrl,
      sitemapStatusCode: result.sitemapStatusCode,
      timestamp: result.timestamp,
      totalLinks: result.totalLinks,
      brokenLinks: result.brokenLinks,
      internalLinks: result.internalLinks,
      externalLinks: result.externalLinks,
      scanDuration: result.scanDuration,
      pagesScanned: result.pagesScanned,
      totalPagesInSitemap: result.totalPagesInSitemap,
      scanCompleted: result.scanCompleted,
      newLastScannedPageIndex: result.newLastScannedPageIndex,
      pagesCompleted: result.pagesCompleted,
      currentBatchStart: result.currentBatchStart,
      currentBatchEnd: result.currentBatchEnd,
    );
  }
}
