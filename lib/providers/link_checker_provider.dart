import 'package:flutter/material.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../services/link_checker_service.dart';

/// State for link checking operation
enum LinkCheckState { idle, checking, completed, error }

/// Provider for managing link checking operations
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerService _linkCheckerService = LinkCheckerService();

  // State variables
  final Map<String, LinkCheckState> _checkStates = {};
  final Map<String, LinkCheckResult?> _resultCache = {};
  final Map<String, List<BrokenLink>> _brokenLinksCache = {};
  final Map<String, String> _errors = {};
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};

  // Getters

  /// Get the current check state for a site
  LinkCheckState getCheckState(String siteId) {
    return _checkStates[siteId] ?? LinkCheckState.idle;
  }

  /// Get cached result for a site
  LinkCheckResult? getCachedResult(String siteId) {
    return _resultCache[siteId];
  }

  /// Get cached broken links for a site
  List<BrokenLink> getCachedBrokenLinks(String siteId) {
    return _brokenLinksCache[siteId] ?? [];
  }

  /// Get error message for a site
  String? getError(String siteId) {
    return _errors[siteId];
  }

  /// Get progress for a site (returns checked/total)
  (int checked, int total) getProgress(String siteId) {
    return (_checkedCounts[siteId] ?? 0, _totalCounts[siteId] ?? 0);
  }

  /// Check if a site is currently being checked
  bool isChecking(String siteId) {
    return _checkStates[siteId] == LinkCheckState.checking;
  }

  /// Check links on a site
  Future<void> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = false,
  }) async {
    final siteId = site.id;

    // Don't start a new check if already checking
    if (isChecking(siteId)) {
      return;
    }

    // Reset state
    _checkStates[siteId] = LinkCheckState.checking;
    _errors.remove(siteId);
    _checkedCounts[siteId] = 0;
    _totalCounts[siteId] = 0;
    notifyListeners();

    try {
      // Perform the link check with progress callback
      final result = await _linkCheckerService.checkSiteLinks(
        site,
        checkExternalLinks: checkExternalLinks,
        onProgress: (checked, total) {
          _checkedCounts[siteId] = checked;
          _totalCounts[siteId] = total;
          notifyListeners();
        },
      );

      // Cache the result
      _resultCache[siteId] = result;

      // Fetch broken links
      final brokenLinks = await _linkCheckerService.getBrokenLinks(siteId);
      _brokenLinksCache[siteId] = brokenLinks;

      // Update state to completed
      _checkStates[siteId] = LinkCheckState.completed;
      notifyListeners();
    } catch (e) {
      // Handle error
      _checkStates[siteId] = LinkCheckState.error;
      _errors[siteId] = e.toString();
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

        // Also load broken links
        final brokenLinks = await _linkCheckerService.getBrokenLinks(siteId);
        _brokenLinksCache[siteId] = brokenLinks;

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

  /// Clear broken links for a site
  Future<void> clearBrokenLinks(String siteId) async {
    try {
      await _linkCheckerService.clearBrokenLinks(siteId);
      _brokenLinksCache.remove(siteId);
      _resultCache.remove(siteId);
      _checkStates[siteId] = LinkCheckState.idle;
      notifyListeners();
    } catch (e) {
      _errors[siteId] = 'Failed to clear broken links: $e';
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
}
