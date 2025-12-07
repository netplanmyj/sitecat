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
  bool _hasLifetimeAccess = false;

  // Cooldown interval after any scan-related action (Start/Stop/Continue)
  static const Duration defaultCooldown = Duration(seconds: 30);

  // State variables
  final Map<String, LinkCheckState> _checkStates = {};
  final Map<String, LinkCheckResult?> _resultCache = {};
  final Map<String, List<BrokenLink>> _brokenLinksCache = {};
  final Map<String, String> _errors = {};
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};
  final Map<String, DateTime> _cooldownUntil = {};
  final Map<String, List<LinkCheckResult>> _checkHistory = {};
  final Map<String, bool> _isProcessingExternalLinks = {};
  final Map<String, int> _externalLinksChecked = {};
  final Map<String, int> _externalLinksTotal = {};
  final Map<String, int?> _currentSitemapStatusCode = {};
  final Map<String, bool> _cancelRequested = {};

  // All results across sites
  List<({String siteId, LinkCheckResult result})> _allCheckHistory = [];

  // Getters

  /// Update premium status and configure service accordingly
  // TODO(#210): Security - Move premium limit enforcement to backend
  // Currently, limits are enforced client-side which can be bypassed.
  // Future implementation should validate entitlements on the server
  // and have backend dictate allowed limits per user.
  void setHasLifetimeAccess(bool hasAccess) {
    if (_hasLifetimeAccess != hasAccess) {
      _hasLifetimeAccess = hasAccess;
      _linkCheckerService.setHistoryLimit(hasAccess);
      _linkCheckerService.setPageLimit(hasAccess);
      notifyListeners();
    }
  }

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

  /// Get current sitemap status code (updated in real-time during scan)
  int? getCurrentSitemapStatusCode(String siteId) {
    return _currentSitemapStatusCode[siteId];
  }

  /// Request cancellation of ongoing scan
  void cancelScan(String siteId) {
    _cancelRequested[siteId] = true;
    _startCooldown(siteId);
    notifyListeners();
  }

  /// Check if cancellation was requested for a site
  bool isCancelRequested(String siteId) {
    return _cancelRequested[siteId] ?? false;
  }

  /// Check if a site is currently being checked
  bool isChecking(String siteId) {
    return _checkStates[siteId] == LinkCheckState.checking;
  }

  /// Trigger cooldown for a site (used after any scan-related action)
  void _startCooldown(String siteId, {Duration? duration}) {
    _cooldownUntil[siteId] = DateTime.now().add(duration ?? defaultCooldown);
    notifyListeners();
  }

  /// Check if a site is currently in cooldown window
  bool isInCooldown(String siteId) {
    final cooldownUntil = _cooldownUntil[siteId];
    if (cooldownUntil == null) return false;
    return DateTime.now().isBefore(cooldownUntil);
  }

  /// Check if a site can be checked (respects cooldown window)
  bool canCheckSite(String siteId) {
    return !isInCooldown(siteId);
  }

  /// Get remaining time until next check is allowed
  Duration? getTimeUntilNextCheck(String siteId) {
    final cooldownUntil = _cooldownUntil[siteId];
    if (cooldownUntil == null) return null;

    final remaining = cooldownUntil.difference(DateTime.now());
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
    final siteId = site.id;

    // Disable checking in demo mode
    if (_isDemoMode) {
      _errors[siteId] = 'Link checking is not available in demo mode';
      notifyListeners();
      return;
    }

    // Don't start a new check if already checking
    if (isChecking(siteId)) {
      return;
    }

    // Enforce cooldown before starting any scan (start/continue)
    if (isInCooldown(siteId)) {
      final remaining = getTimeUntilNextCheck(siteId);
      if (remaining != null) {
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        throw Exception(
          'Please wait $minutes:${seconds.toString().padLeft(2, '0')} before checking again',
        );
      }
    }

    // Start cooldown immediately on user action
    _startCooldown(siteId);

    // Reset state
    _checkStates[siteId] = LinkCheckState.checking;
    _errors.remove(siteId);
    _cancelRequested[siteId] = false; // Reset cancel flag

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
        onSitemapStatusUpdate: (statusCode) {
          // Update current sitemap status in real-time
          _currentSitemapStatusCode[siteId] = statusCode;
          notifyListeners();
        },
        shouldCancel: () => isCancelRequested(siteId),
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

      // Always enforce cooldown after a completed scan batch.
      // This is intentional: cooldown is set both at scan start (line 215) and
      // completion (here). This ensures minimum spacing between consecutive batches.
      // Do not remove unless you fully understand the cooldown design.
      _startCooldown(siteId);

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

      // Enforce cooldown after an error to prevent immediate retries.
      // Cooldown is set even on failure to maintain consistent rate limiting.
      _startCooldown(siteId);

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
