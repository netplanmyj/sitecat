import 'package:logger/logger.dart';
import '../models/broken_link.dart';

/// Manages caching of link check results and history
class LinkCheckerCache {
  final Logger _logger = Logger();

  // Cache storage
  final Map<String, LinkCheckResult?> _resultCache = {};
  final Map<String, List<BrokenLink>> _brokenLinksCache = {};
  final Map<String, List<LinkCheckResult>> _checkHistory = {};
  final Map<String, int?> _currentSitemapStatusCode = {};

  // All results across sites (for global history)
  final List<({String siteId, LinkCheckResult result})> _allCheckHistory = [];

  /// Save a link check result to cache
  void saveResult(String siteId, LinkCheckResult result) {
    _resultCache[siteId] = result;
    _logger.d('Saved result for $siteId');
  }

  /// Save broken links to cache
  void saveBrokenLinks(String siteId, List<BrokenLink> links) {
    _brokenLinksCache[siteId] = links;
    _logger.d('Saved ${links.length} broken links for $siteId');
  }

  /// Add a result to check history for a specific site
  void addToHistory(String siteId, LinkCheckResult result) {
    if (!_checkHistory.containsKey(siteId)) {
      _checkHistory[siteId] = [];
    }
    _checkHistory[siteId]!.insert(
      0,
      result,
    ); // Add to front (most recent first)

    // Also add to global history
    _allCheckHistory.insert(0, (siteId: siteId, result: result));

    _logger.d('Added result to history for $siteId');
  }

  /// Get the most recent cached result for a site
  LinkCheckResult? getResult(String siteId) {
    return _resultCache[siteId];
  }

  /// Get cached broken links for a site
  List<BrokenLink> getBrokenLinks(String siteId) {
    return _brokenLinksCache[siteId] ?? [];
  }

  /// Get check history for a specific site
  List<LinkCheckResult> getHistory(String siteId, {int limit = 50}) {
    final history = _checkHistory[siteId] ?? [];
    return history.take(limit).toList();
  }

  /// Get all check history across all sites
  List<({String siteId, LinkCheckResult result})> getAllHistory({
    int limit = 50,
  }) {
    return _allCheckHistory.take(limit).toList();
  }

  /// Set check history for a specific site, replacing existing history atomically
  /// Keeps global history in sync
  void setHistory(String siteId, List<LinkCheckResult> results) {
    _checkHistory[siteId] = results;
    // Remove old entries for this site from global history
    _allCheckHistory.removeWhere((item) => item.siteId == siteId);
    // Add new entries for this site to global history (most recent first)
    for (final result in results) {
      _allCheckHistory.add((siteId: siteId, result: result));
    }
    _logger.d('Loaded ${results.length} history items for $siteId');
  }

  /// Set global history across all sites, replacing existing history atomically
  void setAllHistory(
    List<({String siteId, LinkCheckResult checkResult})> results,
  ) {
    _allCheckHistory.clear();
    _allCheckHistory.addAll(
      results
          .map((item) => (siteId: item.siteId, result: item.checkResult))
          .toList(),
    );
    _logger.d('Loaded ${results.length} global history items');
  }

  /// Delete a specific result from history and caches
  void deleteResult(String siteId, String resultId) {
    // Remove from site-specific history
    if (_checkHistory.containsKey(siteId)) {
      _checkHistory[siteId]!.removeWhere((result) => result.id == resultId);
      _logger.d('Deleted result $resultId from $siteId history');
    }

    // Remove from global history
    _allCheckHistory.removeWhere(
      (item) => item.siteId == siteId && item.result.id == resultId,
    );

    // Remove from result cache if the cached result matches the resultId
    if (_resultCache.containsKey(siteId)) {
      final cachedResult = _resultCache[siteId];
      if (cachedResult != null && cachedResult.id == resultId) {
        _resultCache.remove(siteId);
        _logger.d('Removed result $resultId from result cache for $siteId');
      }
    }

    // Remove from broken links cache if the result was deleted
    if (!_resultCache.containsKey(siteId)) {
      _brokenLinksCache.remove(siteId);
      _logger.d(
        'Removed broken links cache for $siteId due to result deletion',
      );
    }
  }

  /// Set the current sitemap status code for a site
  void setSitemapStatusCode(String siteId, int? statusCode) {
    _currentSitemapStatusCode[siteId] = statusCode;
    _logger.d('Set sitemap status code for $siteId: $statusCode');
  }

  /// Get the current sitemap status code for a site
  int? getSitemapStatusCode(String siteId) {
    return _currentSitemapStatusCode[siteId];
  }

  /// Clear all cache for a specific site
  void clearCache(String siteId) {
    _resultCache.remove(siteId);
    _brokenLinksCache.remove(siteId);
    _checkHistory.remove(siteId);
    _currentSitemapStatusCode.remove(siteId);

    // Remove from global history
    _allCheckHistory.removeWhere((item) => item.siteId == siteId);

    _logger.d('Cleared cache for $siteId');
  }

  /// Clear all caches completely
  void clearAllCaches() {
    _resultCache.clear();
    _brokenLinksCache.clear();
    _checkHistory.clear();
    _currentSitemapStatusCode.clear();
    _allCheckHistory.clear();
    _logger.d('Cleared all caches');
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'resultCacheSize': _resultCache.length,
      'brokenLinksCacheSize': _brokenLinksCache.length,
      'checkHistorySize': _checkHistory.length,
      'sitemapStatusCodeSize': _currentSitemapStatusCode.length,
      'globalHistorySize': _allCheckHistory.length,
    };
  }
}
