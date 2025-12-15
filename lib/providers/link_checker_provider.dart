import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../services/cooldown_service.dart';
import '../services/link_checker_service.dart';
import '../services/site_service.dart';
import '../services/demo_service.dart';
import '../utils/url_utils.dart';
import 'link_checker_cache.dart';
import 'link_checker_progress.dart';

/// State for link checking operation
enum LinkCheckState { idle, checking, completed, error }

/// Provider for managing link checking operations
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerClient _linkCheckerService;
  final SiteUpdater _siteService;
  final CooldownService _cooldownService;
  final LinkCheckerCache _cache;
  final LinkCheckerProgress _progress;
  final Logger _logger = Logger();
  bool _isDemoMode = false;
  bool _hasLifetimeAccess = false;

  // Cooldown interval after any scan-related action (Start/Stop/Continue)
  // Unified to 10 seconds to match MonitoringProvider's minimumCheckInterval (#256)
  static const Duration defaultCooldown = Duration(seconds: 10);

  // State variables (UI state only - cache and progress delegated to separate classes)
  final Map<String, LinkCheckState> _checkStates = {};
  final Map<String, String> _errors = {};

  LinkCheckerProvider({
    LinkCheckerClient? linkCheckerService,
    SiteUpdater? siteService,
    CooldownService? cooldownService,
    LinkCheckerCache? cache,
    LinkCheckerProgress? progress,
  }) : _linkCheckerService = linkCheckerService ?? LinkCheckerService(),
       _siteService = siteService ?? SiteService(),
       _cooldownService = cooldownService ?? CooldownService(),
       _cache = cache ?? LinkCheckerCache(),
       _progress = progress ?? LinkCheckerProgress();

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
    return _cache.getResult(siteId);
  }

  /// Get cached broken links for a site
  List<BrokenLink> getCachedBrokenLinks(String siteId) {
    if (_isDemoMode) {
      return DemoService.getBrokenLinks(siteId);
    }
    return _cache.getBrokenLinks(siteId);
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
    return (_progress.getCheckedCount(siteId), _progress.getTotalCount(siteId));
  }

  /// Check if external links are being processed
  bool isProcessingExternalLinks(String siteId) {
    return _progress.isProcessingExternalLinks(siteId);
  }

  /// Get external links checking progress (returns checked/total)
  (int checked, int total) getExternalLinksProgress(String siteId) {
    return (
      _progress.getExternalLinksChecked(siteId),
      _progress.getExternalLinksTotal(siteId),
    );
  }

  /// Get current sitemap status code (updated in real-time during scan)
  int? getCurrentSitemapStatusCode(String siteId) {
    return _cache.getSitemapStatusCode(siteId);
  }

  /// Request cancellation of ongoing scan
  void cancelScan(String siteId) {
    _progress.setCancelRequested(siteId, true);
    _startCooldown(siteId);
    notifyListeners();
  }

  @visibleForTesting
  void setCheckedCounts(String siteId, int value) {
    _progress.setCheckedCount(siteId, value);
  }

  @visibleForTesting
  Future<void> saveProgressOnInterruption({
    required Site site,
    required String siteId,
  }) async {
    final currentProgress = _progress.getCheckedCount(siteId);
    if (currentProgress <= 0) {
      return; // Nothing to save
    }

    try {
      await _siteService.updateSite(
        site.copyWith(lastScannedPageIndex: currentProgress),
      );
    } catch (updateError) {
      // Log but don't fail if update fails
      final previous = _errors[siteId];
      final message =
          'Failed to save progress: $updateError${previous != null ? '\n$previous' : ''}';
      _errors[siteId] = message;
    }
  }

  /// Check if cancellation was requested for a site
  bool isCancelRequested(String siteId) {
    return _progress.isCancelRequested(siteId);
  }

  /// Check if a site is currently being checked
  bool isChecking(String siteId) {
    return _checkStates[siteId] == LinkCheckState.checking;
  }

  /// Trigger cooldown for a site (used after any scan-related action)
  void _startCooldown(String siteId, {Duration? duration}) {
    _cooldownService.startCooldown(siteId, duration ?? defaultCooldown);
    notifyListeners();
  }

  /// Check if a site is currently in cooldown window
  bool isInCooldown(String siteId) {
    return !_cooldownService.canPerformAction(siteId);
  }

  /// Check if a site can be checked (respects cooldown window)
  bool canCheckSite(String siteId) {
    return !isInCooldown(siteId);
  }

  /// Get remaining time until next check is allowed
  Duration? getTimeUntilNextCheck(String siteId) {
    return _cooldownService.getTimeUntilNextCheck(siteId);
  }

  /// Get pre-calculated target page count for a site
  /// Returns null if not yet calculated or calculation failed
  int? getPrecalculatedPageCount(String siteId) {
    if (_isDemoMode) {
      // Demo mode: return demo site data
      // This would typically be a constant for demo sites
      return null; // or return a demo value
    }
    return _progress.getPrecalculatedPageCount(siteId);
  }

  /// Pre-calculate the total page count for a site by loading its sitemap
  /// This determines how many pages will be scanned based on the site's current sitemap
  /// and excluded paths configuration.
  Future<int?> precalculatePageCount(Site site) async {
    if (_isDemoMode) {
      // Demo mode: return null (demo sites don't have real page counts)
      return null;
    }

    try {
      // Use the link checker service's lightweight sitemap loader
      final pageCount = await _linkCheckerService.loadSitemapPageCount(site);

      if (pageCount != null && pageCount > 0) {
        // Cache the result
        _progress.setPrecalculatedPageCount(site.id, pageCount);
        notifyListeners();
      }

      return pageCount;
    } catch (e) {
      // Log error but don't throw - gracefully handle failures
      _logger.e('Error pre-calculating page count for ${site.id}: $e');
      return null;
    }
  }

  /// Clear the cached pre-calculated page count for a site.
  /// Should be called after the site's configuration (e.g., excludedPaths) changes.
  void clearPrecalculatedPageCount(String siteId) {
    _progress.clearPrecalculatedPageCount(siteId);
    notifyListeners();
  }

  /// Get check history for a site
  List<LinkCheckResult> getCheckHistory(String siteId) {
    return _cache.getHistory(siteId);
  }

  /// Load check history from Firestore
  Future<void> loadCheckHistory(String siteId, {int limit = 50}) async {
    try {
      final results = await _linkCheckerService.getCheckResults(
        siteId,
        limit: limit,
      );
      for (final result in results) {
        _cache.addToHistory(siteId, result);
      }
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

    // Reset state
    _checkStates[siteId] = LinkCheckState.checking;
    _errors.remove(siteId);
    _progress.setCancelRequested(siteId, false); // Reset cancel flag

    // Store previous progress before potentially resetting
    final previousChecked = _progress.getCheckedCount(siteId);
    final previousTotal = _progress.getTotalCount(siteId);

    // Reset progress counters for a fresh scan, but keep previous progress when continuing
    if (!continueFromLastScan) {
      _progress.setCheckedCount(siteId, 0);
      // Use precalculated page count if available to avoid recalculating sitemap
      final precalculatedTotal = _progress.getPrecalculatedPageCount(siteId);
      _progress.setTotalCount(siteId, precalculatedTotal ?? 0);
    } else {
      // Preserve existing progress to avoid flashing 0 on resume
      // Prefer pagesCompleted from cached result for accuracy
      final latestResult = _cache.getResult(siteId);
      _progress.setCheckedCount(
        siteId,
        latestResult?.pagesCompleted ??
            latestResult?.pagesScanned ??
            site.lastScannedPageIndex,
      );
      // Use precalculated page count if available, otherwise let onProgress update it
      final precalculatedTotal = _progress.getPrecalculatedPageCount(siteId);
      _progress.setTotalCount(siteId, precalculatedTotal ?? 0);
    }
    _progress.setIsProcessingExternalLinks(siteId, false);
    _progress.setExternalLinksProgress(siteId, 0, 0);

    notifyListeners();

    try {
      // Perform the link check with progress callback
      // Pass precalculated page count to optimize sitemap loading
      final precalculatedTotal = _progress.getPrecalculatedPageCount(siteId);
      final result = await _linkCheckerService.checkSiteLinks(
        site,
        checkExternalLinks: checkExternalLinks,
        continueFromLastScan: continueFromLastScan,
        precalculatedPageCount: precalculatedTotal,
        onProgress: (checked, total) {
          _progress.setCheckedCount(siteId, checked);
          // Only update total if it's different (sitemap might have changed)
          if (total != _progress.getTotalCount(siteId)) {
            _progress.setTotalCount(siteId, total);
          }

          notifyListeners();
        },
        onExternalLinksProgress: (checked, total) {
          _progress.setExternalLinksProgress(siteId, checked, total);

          // Mark as processing links when this callback is first called
          if (!_progress.isProcessingExternalLinks(siteId)) {
            _progress.setIsProcessingExternalLinks(siteId, true);
          }

          notifyListeners();
        },
        onSitemapStatusUpdate: (statusCode) {
          // Update current sitemap status in real-time
          _cache.setSitemapStatusCode(siteId, statusCode);
          notifyListeners();
        },
        shouldCancel: () => isCancelRequested(siteId),
      );

      // Cache the result
      _cache.saveResult(siteId, result);
      _cache.addToHistory(siteId, result);

      // Update state based on whether all pages were scanned
      // - If scanCompleted=true: Mark as LinkCheckState.completed (site scan done)
      // - If scanCompleted=false: Mark as LinkCheckState.idle (batch complete, ready to continue)
      //   This ensures Stop button becomes disabled during cooldown, and Start/Continue become enabled only after cooldown expires
      if (result.scanCompleted) {
        _checkStates[siteId] = LinkCheckState.completed;
      } else {
        _checkStates[siteId] = LinkCheckState.idle;
      }

      // Preserve final progress counts after completion (don't reset to 0)
      // This keeps the progress bar visible with final stats (#247, #262)
      _progress.setCheckedCount(siteId, result.pagesScanned);
      _progress.setTotalCount(siteId, result.totalPagesInSitemap);

      // Keep progress display (don't reset _isProcessingExternalLinks)
      notifyListeners(); // Immediate UI update with scan results

      // Fetch broken links using resultId (async, but UI already shows results)
      if (result.id != null) {
        final brokenLinks = await _linkCheckerService.getBrokenLinks(
          result.id!,
        );
        _cache.saveBrokenLinks(siteId, brokenLinks);
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
      _progress.setIsProcessingExternalLinks(
        siteId,
        false,
      ); // Reset flag on error

      // Save current progress on cancellation or error
      await saveProgressOnInterruption(site: site, siteId: siteId);

      // Restore previous progress display if a NEW scan (not continue) failed
      // BEFORE making any progress. This preserves the old completion indicator
      // in the UI while keeping the actual lastScannedPageIndex unchanged in DB.
      // If currentProgress > 0, we've already saved it above.
      //
      // This only applies when:
      // - Starting a fresh scan (!continueFromLastScan)
      // - The scan fails immediately (currentProgress == 0)
      // - There was previous progress to display (previousChecked > 0)
      if (!continueFromLastScan && previousChecked > 0) {
        final currentProgress = _progress.getCheckedCount(siteId);
        if (currentProgress == 0) {
          _progress.setCheckedCount(siteId, previousChecked);
          _progress.setTotalCount(siteId, previousTotal);
        }
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
        _cache.saveResult(siteId, result);

        // Also load broken links using resultId
        if (result.id != null) {
          final brokenLinks = await _linkCheckerService.getBrokenLinks(
            result.id!,
          );
          _cache.saveBrokenLinks(siteId, brokenLinks);
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
      final cachedResult = _cache.getResult(siteId);
      if (cachedResult?.id == resultId) {
        _cache.deleteResult(siteId, resultId);
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
    _progress.resetProgress(siteId);
    notifyListeners();
  }

  /// Save current scan progress to Results and reset scan state
  /// Called when user navigates away during an active scan
  Future<void> saveProgressAndReset(String siteId) async {
    try {
      // Only save if actively scanning
      if (!isChecking(siteId)) {
        return;
      }

      // Get current progress
      final checkedCount = _progress.getCheckedCount(siteId);
      final totalCount = _progress.getTotalCount(siteId);
      final cachedResult = _cache.getResult(siteId);

      // If no progress, just reset
      if (checkedCount == 0 || cachedResult == null) {
        resetState(siteId);
        return;
      }

      // Create interrupted result with current progress
      final interruptedResult = cachedResult.copyWith(
        pagesScanned: checkedCount,
        totalPagesInSitemap: totalCount,
        scanCompleted: false, // Mark as incomplete
        timestamp: DateTime.now(),
      );

      // Save to Firestore
      await _linkCheckerService.saveInterruptedResult(interruptedResult);

      // Reset scan state
      resetState(siteId);
    } catch (e) {
      _errors[siteId] = 'Failed to save progress: $e';
      notifyListeners();
    }
  }

  /// Clear all cached data
  void clearAllCache() {
    _checkStates.clear();
    _cache.clearAllCaches();
    _errors.clear();
    _progress.clearAll();
    notifyListeners();
  }

  /// Get all check history across all sites
  List<({String siteId, LinkCheckResult result})> getAllCheckHistory() {
    return _cache.getAllHistory();
  }

  /// Load all check history from Firestore (across all sites)
  Future<void> loadAllCheckHistory({int limit = 50}) async {
    try {
      final results = await _linkCheckerService.getAllCheckResults(
        limit: limit,
      );

      // Convert List<LinkCheckResult> to List<({String siteId, LinkCheckResult checkResult})>
      _cache.setAllHistory(
        results
            .map((result) => (siteId: result.siteId, checkResult: result))
            .toList(),
      );

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
      final cached = _cache.getBrokenLinks(siteId);
      if (cached.isNotEmpty) {
        // Verify if this is for the same result
        final cachedResult = _cache.getResult(siteId);
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
