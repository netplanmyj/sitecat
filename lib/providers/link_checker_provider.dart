import 'package:flutter/material.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../services/link_checker_service.dart';
import '../services/site_service.dart';
import '../services/demo_service.dart';
import '../utils/url_utils.dart';

/// State for link checking operation
enum LinkCheckState { idle, checking, completed, error }

/// Provider for managing link checking operations
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerService _linkCheckerService = LinkCheckerService();
  final SiteService _siteService = SiteService();
  bool _isDemoMode = false;

  // Minimum interval between checks (1 minute for debugging)
  static const Duration minimumCheckInterval = Duration(minutes: 1);

  // State variables
  final Map<String, LinkCheckState> _checkStates = {};
  final Map<String, LinkCheckResult?> _resultCache = {};
  final Map<String, List<BrokenLink>> _brokenLinksCache = {};
  final Map<String, String> _errors = {};
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};
  final Map<String, DateTime> _lastCheckTime = {};
  final Map<String, List<LinkCheckResult>> _checkHistory = {};
  final Map<String, bool> _isProcessingExternalLinks = {};
  final Map<String, int> _externalLinksChecked = {};
  final Map<String, int> _externalLinksTotal = {};

  // All results across sites
  List<({String siteId, LinkCheckResult result})> _allCheckHistory = [];

  // Getters

  /// Get the current check state for a site
  LinkCheckState getCheckState(String siteId) {
    return _checkStates[siteId] ?? LinkCheckState.idle;
  }

  /// Get cached result for a site
  LinkCheckResult? getCachedResult(String siteId) {
    if (_isDemoMode) {
      final results = DemoService.getLinkCheckResults(siteId);
      return results.isNotEmpty ? results.first : null;
    }
    return _resultCache[siteId];
  }

  /// Get cached broken links for a site
  List<BrokenLink> getCachedBrokenLinks(String siteId) {
    if (_isDemoMode) {
      return DemoService.getBrokenLinks(siteId);
    }
    return _brokenLinksCache[siteId] ?? [];
  }

  /// Initialize with demo mode flag
  void initialize({bool isDemoMode = false}) {
    _isDemoMode = isDemoMode;
  }

  /// Get error message for a site
  String? getError(String siteId) {
    return _errors[siteId];
  }

  /// Get progress for a site (returns checked/total)
  (int checked, int total) getProgress(String siteId) {
    return (_checkedCounts[siteId] ?? 0, _totalCounts[siteId] ?? 0);
  }

  /// Check if external links are being processed
  bool isProcessingExternalLinks(String siteId) {
    return _isProcessingExternalLinks[siteId] ?? false;
  }

  /// Get external links checking progress (returns checked/total)
  (int checked, int total) getExternalLinksProgress(String siteId) {
    return (
      _externalLinksChecked[siteId] ?? 0,
      _externalLinksTotal[siteId] ?? 0,
    );
  }

  /// Check if a site is currently being checked
  bool isChecking(String siteId) {
    return _checkStates[siteId] == LinkCheckState.checking;
  }

  /// Check if a site can be checked (respects minimum interval)
  bool canCheckSite(String siteId) {
    final lastCheck = _lastCheckTime[siteId];
    if (lastCheck == null) return true;

    final timeSinceLastCheck = DateTime.now().difference(lastCheck);
    return timeSinceLastCheck >= minimumCheckInterval;
  }

  /// Get remaining time until next check is allowed
  Duration? getTimeUntilNextCheck(String siteId) {
    final lastCheck = _lastCheckTime[siteId];
    if (lastCheck == null) return null;

    final timeSinceLastCheck = DateTime.now().difference(lastCheck);
    final remaining = minimumCheckInterval - timeSinceLastCheck;

    return remaining.isNegative ? null : remaining;
  }

  /// Get check history for a site
  List<LinkCheckResult> getCheckHistory(String siteId) {
    return _checkHistory[siteId] ?? [];
  }

  /// Load check history from Firestore
  Future<void> loadCheckHistory(String siteId, {int limit = 50}) async {
    try {
      final results = await _linkCheckerService.getCheckResults(
        siteId,
        limit: limit,
      );
      _checkHistory[siteId] = results;
      notifyListeners();
    } catch (e) {
      _errors[siteId] = 'Failed to load check history: $e';
      notifyListeners();
    }
  }

  /// Check if a link check result has a URL mismatch
  /// Returns true if the checked URL differs from the current site URL
  bool hasUrlMismatch(LinkCheckResult result, Site site) {
    return UrlUtils.hasUrlMismatch(result.checkedUrl, site.url);
  }

  /// Check links on a site
  Future<void> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = false,
    bool continueFromLastScan = false,
  }) async {
    // Disable checking in demo mode
    if (_isDemoMode) {
      throw Exception('Link checking is not available in demo mode');
    }

    final siteId = site.id;

    // Don't start a new check if already checking
    if (isChecking(siteId)) {
      return;
    }

    // Check if minimum interval has passed (skip for continue scan)
    if (!continueFromLastScan && !canCheckSite(siteId)) {
      final remaining = getTimeUntilNextCheck(siteId);
      if (remaining != null) {
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        throw Exception(
          'Please wait $minutes:${seconds.toString().padLeft(2, '0')} before checking again',
        );
      }
    }

    // Reset state
    _checkStates[siteId] = LinkCheckState.checking;
    _errors.remove(siteId);

    // Store previous progress before potentially resetting
    final previousChecked = _checkedCounts[siteId] ?? 0;
    final previousTotal = _totalCounts[siteId] ?? 0;

    // Reset progress counters at the start of scan (both new and continue)
    _checkedCounts[siteId] = 0;
    _totalCounts[siteId] = 0;
    _isProcessingExternalLinks[siteId] = false;
    _externalLinksChecked[siteId] = 0;
    _externalLinksTotal[siteId] = 0;

    notifyListeners();

    try {
      // Perform the link check with progress callback
      final result = await _linkCheckerService.checkSiteLinks(
        site,
        checkExternalLinks: checkExternalLinks,
        continueFromLastScan: continueFromLastScan,
        onProgress: (checked, total) {
          _checkedCounts[siteId] = checked;
          _totalCounts[siteId] = total;

          notifyListeners();
        },
        onExternalLinksProgress: (checked, total) {
          _externalLinksChecked[siteId] = checked;
          _externalLinksTotal[siteId] = total;

          // Mark as processing links when this callback is first called
          if (!(_isProcessingExternalLinks[siteId] ?? false)) {
            _isProcessingExternalLinks[siteId] = true;
          }

          notifyListeners();
        },
      );

      // Cache the result
      _resultCache[siteId] = result;

      // Update state to completed and notify immediately
      _checkStates[siteId] = LinkCheckState.completed;
      // Keep progress display (don't reset _isProcessingExternalLinks)
      notifyListeners(); // Immediate UI update with scan results

      // Fetch broken links using resultId (async, but UI already shows results)
      if (result.id != null) {
        final brokenLinks = await _linkCheckerService.getBrokenLinks(
          result.id!,
        );
        _brokenLinksCache[siteId] = brokenLinks;
      }

      // Update site's lastScannedPageIndex
      await _siteService.updateSite(
        site.copyWith(lastScannedPageIndex: result.newLastScannedPageIndex),
      );

      // Record check time
      _lastCheckTime[siteId] = DateTime.now();

      // Notify again after broken links are loaded
      notifyListeners();
    } catch (e) {
      // Handle error - preserve the last known state for continue functionality
      _checkStates[siteId] = LinkCheckState.error;
      _errors[siteId] = e.toString();
      _isProcessingExternalLinks[siteId] = false; // Reset flag on error

      // Restore previous progress if this was a new scan that failed early
      // This ensures Continue button works correctly after an error
      if (!continueFromLastScan && previousChecked > 0) {
        _checkedCounts[siteId] = previousChecked;
        _totalCounts[siteId] = previousTotal;
      }

      notifyListeners();
      rethrow;
    }
  }

  /// Load latest check result from database
  Future<void> loadLatestResult(String siteId) async {
    try {
      final result = await _linkCheckerService.getLatestCheckResult(siteId);
      if (result != null) {
        _resultCache[siteId] = result;

        // Also load broken links using resultId
        if (result.id != null) {
          final brokenLinks = await _linkCheckerService.getBrokenLinks(
            result.id!,
          );
          _brokenLinksCache[siteId] = brokenLinks;
        }

        _checkStates[siteId] = LinkCheckState.completed;
      } else {
        _checkStates[siteId] = LinkCheckState.idle;
      }
      notifyListeners();
    } catch (e) {
      _checkStates[siteId] = LinkCheckState.error;
      _errors[siteId] = 'Failed to load result: $e';
      notifyListeners();
    }
  }

  /// Delete a specific link check result
  Future<void> deleteLinkCheckResult(String siteId, String resultId) async {
    try {
      await _linkCheckerService.deleteLinkCheckResult(resultId);

      // If this was the cached result, clear it and reload
      final cachedResult = _resultCache[siteId];
      if (cachedResult?.id == resultId) {
        _resultCache.remove(siteId);
        _brokenLinksCache.remove(siteId);
        // Try to load the next most recent result
        await loadLatestResult(siteId);
      }

      notifyListeners();
    } catch (e) {
      _errors[siteId] = 'Failed to delete result: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Reset state for a site
  void resetState(String siteId) {
    _checkStates.remove(siteId);
    _errors.remove(siteId);
    _checkedCounts.remove(siteId);
    _totalCounts.remove(siteId);
    notifyListeners();
  }

  /// Clear all cached data
  void clearAllCache() {
    _checkStates.clear();
    _resultCache.clear();
    _brokenLinksCache.clear();
    _errors.clear();
    _checkedCounts.clear();
    _totalCounts.clear();
    notifyListeners();
  }

  /// Get all check history across all sites
  List<({String siteId, LinkCheckResult result})> getAllCheckHistory() {
    return _allCheckHistory;
  }

  /// Load all check history from Firestore (across all sites)
  Future<void> loadAllCheckHistory({int limit = 50}) async {
    try {
      final results = await _linkCheckerService.getAllCheckResults(
        limit: limit,
      );

      _allCheckHistory = results
          .map((result) => (siteId: result.siteId, result: result))
          .toList();

      notifyListeners();
    } catch (e) {
      // Handle error silently or log it
      debugPrint('Error loading all check history: $e');
    }
  }

  /// Get broken links for a specific result
  Future<List<BrokenLink>> getBrokenLinksForResult(
    String siteId,
    String resultId,
  ) async {
    try {
      // Check cache first
      final cached = _brokenLinksCache[siteId];
      if (cached != null && cached.isNotEmpty) {
        // Verify if this is for the same result
        final cachedResult = _resultCache[siteId];
        if (cachedResult?.id == resultId) {
          return cached;
        }
      }

      // Fetch from Firestore using resultId
      final brokenLinks = await _linkCheckerService.getBrokenLinks(resultId);
      return brokenLinks;
    } catch (e) {
      debugPrint('Error getting broken links for result: $e');
      return [];
    }
  }
}
