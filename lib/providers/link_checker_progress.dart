import 'package:logger/logger.dart';

/// Manages progress tracking for link checking operations
class LinkCheckerProgress {
  final Logger _logger = Logger();

  // Progress tracking
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};
  final Map<String, int> _externalLinksChecked = {};
  final Map<String, int> _externalLinksTotal = {};
  final Map<String, bool> _isProcessingExternalLinks = {};
  final Map<String, bool> _cancelRequested = {};
  final Map<String, int?> _precalculatedPageCounts = {};

  /// Set the number of checked links for a site
  void setCheckedCount(String siteId, int count) {
    _checkedCounts[siteId] = count;
    _logger.d('Set checked count for $siteId: $count');
  }

  /// Get the number of checked links for a site
  int getCheckedCount(String siteId) {
    return _checkedCounts[siteId] ?? 0;
  }

  /// Set the total number of links for a site
  void setTotalCount(String siteId, int count) {
    _totalCounts[siteId] = count;
    _logger.d('Set total count for $siteId: $count');
  }

  /// Get the total number of links for a site
  int getTotalCount(String siteId) {
    return _totalCounts[siteId] ?? 0;
  }

  /// Get progress as a decimal (0.0 to 1.0)
  double getProgress(String siteId) {
    final total = getTotalCount(siteId);
    if (total == 0) return 0.0;
    return getCheckedCount(siteId) / total;
  }

  /// Get progress as a percentage (0 to 100)
  int getProgressPercentage(String siteId) {
    return (getProgress(siteId) * 100).toInt();
  }

  /// Set progress for external links processing
  void setExternalLinksProgress(String siteId, int checked, int total) {
    _externalLinksChecked[siteId] = checked;
    _externalLinksTotal[siteId] = total;
    _logger.d('Set external links progress for $siteId: $checked/$total');
  }

  /// Get the number of checked external links for a site
  int getExternalLinksChecked(String siteId) {
    return _externalLinksChecked[siteId] ?? 0;
  }

  /// Get the total number of external links for a site
  int getExternalLinksTotal(String siteId) {
    return _externalLinksTotal[siteId] ?? 0;
  }

  /// Get external links progress as a decimal (0.0 to 1.0)
  double getExternalProgress(String siteId) {
    final total = _externalLinksTotal[siteId] ?? 0;
    if (total == 0) return 0.0;
    return (_externalLinksChecked[siteId] ?? 0) / total;
  }

  /// Get external links progress as a percentage
  int getExternalProgressPercentage(String siteId) {
    return (getExternalProgress(siteId) * 100).toInt();
  }

  /// Set flag indicating external links are being processed
  void setIsProcessingExternalLinks(String siteId, bool isProcessing) {
    _isProcessingExternalLinks[siteId] = isProcessing;
    _logger.d('Set processing external links for $siteId: $isProcessing');
  }

  /// Check if external links are being processed
  bool isProcessingExternalLinks(String siteId) {
    return _isProcessingExternalLinks[siteId] ?? false;
  }

  /// Request cancellation of scan for a site
  void setCancelRequested(String siteId, bool requested) {
    _cancelRequested[siteId] = requested;
    _logger.d('Set cancel requested for $siteId: $requested');
  }

  /// Check if cancellation was requested for a site
  bool isCancelRequested(String siteId) {
    return _cancelRequested[siteId] ?? false;
  }

  /// Precalculate and cache page count for a site
  /// (actual calculation done in LinkCheckerService)
  void setPrecalculatedPageCount(String siteId, int? count) {
    _precalculatedPageCounts[siteId] = count;
    if (count != null) {
      _logger.d('Set precalculated page count for $siteId: $count');
    }
  }

  /// Get precalculated page count for a site
  int? getPrecalculatedPageCount(String siteId) {
    return _precalculatedPageCounts[siteId];
  }

  /// Clear precalculated page count for a site
  void clearPrecalculatedPageCount(String siteId) {
    _precalculatedPageCounts.remove(siteId);
    _logger.d('Cleared precalculated page count for $siteId');
  }

  /// Save progress to persist interrupted scan state
  /// (actual Firestore save done in Provider/Service)
  Map<String, dynamic> getProgressSnapshot(String siteId) {
    return {
      'checkedCount': getCheckedCount(siteId),
      'totalCount': getTotalCount(siteId),
      'externalChecked': _externalLinksChecked[siteId] ?? 0,
      'externalTotal': _externalLinksTotal[siteId] ?? 0,
      'isProcessingExternal': isProcessingExternalLinks(siteId),
      'precalculatedPageCount': getPrecalculatedPageCount(siteId),
    };
  }

  /// Restore progress from saved snapshot
  void restoreProgressSnapshot(String siteId, Map<String, dynamic> snapshot) {
    setCheckedCount(siteId, snapshot['checkedCount'] as int? ?? 0);
    setTotalCount(siteId, snapshot['totalCount'] as int? ?? 0);
    setExternalLinksProgress(
      siteId,
      snapshot['externalChecked'] as int? ?? 0,
      snapshot['externalTotal'] as int? ?? 0,
    );
    setIsProcessingExternalLinks(
      siteId,
      snapshot['isProcessingExternal'] as bool? ?? false,
    );
    setPrecalculatedPageCount(
      siteId,
      snapshot['precalculatedPageCount'] as int?,
    );
    _logger.d('Restored progress snapshot for $siteId');
  }

  /// Reset all progress for a site
  void resetProgress(String siteId) {
    _checkedCounts.remove(siteId);
    _totalCounts.remove(siteId);
    _externalLinksChecked.remove(siteId);
    _externalLinksTotal.remove(siteId);
    _isProcessingExternalLinks.remove(siteId);
    _cancelRequested.remove(siteId);
    _precalculatedPageCounts.remove(siteId);
    _logger.d('Reset progress for $siteId');
  }

  /// Clear all progress data
  void clearAll() {
    _checkedCounts.clear();
    _totalCounts.clear();
    _externalLinksChecked.clear();
    _externalLinksTotal.clear();
    _isProcessingExternalLinks.clear();
    _cancelRequested.clear();
    _precalculatedPageCounts.clear();
    _logger.d('Cleared all progress data');
  }

  /// Get progress statistics (for debugging)
  Map<String, dynamic> getProgressStats() {
    return {
      'trackedSites': _checkedCounts.length,
      'totalCheckedCount': _checkedCounts.values.fold(
        0,
        (sum, val) => sum + val,
      ),
      'totalTotalCount': _totalCounts.values.fold(0, (sum, val) => sum + val),
      'sitesProcessingExternal': _isProcessingExternalLinks.values
          .where((v) => v)
          .length,
      'sitesWithCancelRequest': _cancelRequested.values.where((v) => v).length,
      'precalculatedSites': _precalculatedPageCounts.length,
    };
  }
}
