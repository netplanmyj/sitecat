import 'dart:async';
import 'package:flutter/material.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../services/cooldown_service.dart';
import '../services/monitoring_service.dart';

class MonitoringProvider extends ChangeNotifier {
  MonitoringProvider({
    MonitoringService? monitoringService,
    CooldownService? cooldownService,
  }) : _monitoringService = monitoringService ?? MonitoringService(),
       _cooldownService = cooldownService ?? _InMemoryCooldownService();

  final MonitoringService _monitoringService;
  final CooldownService _cooldownService;
  bool _isDemoMode = false;
  bool _hasLifetimeAccess = false;

  // Minimum interval between checks to avoid aggressive polling / rate limits.
  // Set to 10 seconds to improve UX while maintaining reasonable API usage.
  // Backend should handle this frequency; monitor for rate limit issues.
  static const Duration minimumCheckInterval = Duration(seconds: 10);

  // State variables
  final Map<String, List<MonitoringResult>> _resultsBySite = {};
  final Map<String, MonitoringResult?> _quickCheckCache =
      {}; // Cache for quick check results (memory-only)
  final Map<String, bool> _isChecking = {};
  final Map<String, int?> _sitemapStatusCache =
      {}; // Cache for sitemap status code
  String? _error;
  Map<String, StreamSubscription<List<MonitoringResult>>>? _subscriptions;

  // Getters
  String? get error => _error;

  /// Update premium status and configure service accordingly
  void setHasLifetimeAccess(bool hasAccess) {
    if (_hasLifetimeAccess != hasAccess) {
      _hasLifetimeAccess = hasAccess;
      _monitoringService.setHistoryLimit(hasAccess);
      notifyListeners();
    }
  }

  /// Get monitoring results for a specific site (Firestore persisted results only)
  List<MonitoringResult> getSiteResults(String siteId) {
    return _resultsBySite[siteId] ?? [];
  }

  /// Get quick check result for a site (memory-only, not persisted)
  MonitoringResult? getQuickCheckResult(String siteId) {
    return _quickCheckCache[siteId];
  }

  /// Check if a site is currently being monitored
  bool isChecking(String siteId) {
    return _isChecking[siteId] ?? false;
  }

  /// Get the latest result for a site
  MonitoringResult? getLatestResult(String siteId) {
    final results = _resultsBySite[siteId];
    return results != null && results.isNotEmpty ? results.first : null;
  }

  /// Get all monitoring results across all sites
  List<({String siteId, MonitoringResult result})> getAllResults() {
    final allResults = <({String siteId, MonitoringResult result})>[];

    _resultsBySite.forEach((siteId, results) {
      for (final result in results) {
        allResults.add((siteId: siteId, result: result));
      }
    });

    // Sort by timestamp (newest first)
    allResults.sort((a, b) => b.result.timestamp.compareTo(a.result.timestamp));

    return allResults;
  }

  /// Initialize monitoring for all sites
  Future<void> initialize(
    List<String> siteIds, {
    bool isDemoMode = false,
  }) async {
    _isDemoMode = isDemoMode;
    if (_isDemoMode) return; // Skip initialization in demo mode

    for (final siteId in siteIds) {
      listenToSiteResults(siteId);
    }
  }

  /// Initialize monitoring from SiteProvider
  void initializeFromSites(dynamic siteProvider) {
    final sites = siteProvider.sites as List;
    for (final site in sites) {
      listenToSiteResults(site.id);
    }
  }

  @override
  void dispose() {
    _subscriptions?.forEach((key, subscription) {
      subscription.cancel();
    });
    super.dispose();
  }

  /// Start listening to monitoring results for a site
  void listenToSiteResults(String siteId, {int limit = 50}) {
    _subscriptions ??= {};

    // Cancel existing subscription if any
    _subscriptions![siteId]?.cancel();

    _subscriptions![siteId] = _monitoringService
        .getSiteResults(siteId, limit: limit)
        .listen(
          (results) {
            _resultsBySite[siteId] = results;
            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to load monitoring results: $error');
          },
        );
  }

  /// Stop listening to monitoring results for a site
  void stopListeningToSiteResults(String siteId) {
    _subscriptions?[siteId]?.cancel();
    _subscriptions?.remove(siteId);
  }

  /// Check if a site can be checked (respects minimum interval)
  bool canCheckSite(String siteId) {
    return _cooldownService.canPerformAction(siteId);
  }

  /// Get remaining time until next check is allowed
  Duration? getTimeUntilNextCheck(String siteId) {
    return _cooldownService.getTimeUntilNextCheck(siteId);
  }

  /// Perform a manual check on a site (saves to Firestore)
  Future<bool> checkSite(Site site) async {
    return _performCheck(
      site,
      serviceCall: () => _monitoringService.checkSite(site),
      onSuccess: (result) {
        // Update local cache with Firestore-persisted result
        final existingResults = _resultsBySite[site.id] ?? [];
        _resultsBySite[site.id] = [result, ...existingResults];
      },
    );
  }

  /// Perform a quick check on a site (does NOT save to Firestore - memory only).
  ///
  /// Practical differences from [checkSite]:
  /// - No Firestore document is created, so the returned [MonitoringResult] will have
  ///   an empty `id`.
  /// - The site's `lastChecked` timestamp is **not** updated.
  /// - Results are stored in a separate cache and do **not** appear in [getSiteResults]
  ///   or [getAllResults].
  ///
  /// Use this for temporary checks that should only appear in the Site Information card.
  /// Issue #294: Quick Scan results should not appear in Results page.
  Future<bool> quickCheckSite(Site site) async {
    return _performCheck(
      site,
      serviceCall: () => _monitoringService.quickCheckSite(site),
      onSuccess: (result) {
        // Store in separate quick check cache (not mixed with Firestore results)
        _quickCheckCache[site.id] = result;
      },
    );
  }

  /// Internal helper to perform check with common logic
  Future<bool> _performCheck(
    Site site, {
    required Future<MonitoringResult> Function() serviceCall,
    required void Function(MonitoringResult) onSuccess,
  }) async {
    // Disable checking in demo mode
    if (_isDemoMode) {
      _setError('Site monitoring is not available in demo mode');
      return false;
    }

    try {
      _clearError();

      // Check if minimum interval has passed
      if (!canCheckSite(site.id)) {
        final remaining = getTimeUntilNextCheck(site.id);
        if (remaining != null) {
          final minutes = remaining.inMinutes;
          final seconds = remaining.inSeconds % 60;
          _setError(
            'Please wait $minutes:${seconds.toString().padLeft(2, '0')} before checking again',
          );
          return false;
        }
      }

      _setChecking(site.id, true);

      final result = await serviceCall();

      // Execute caller-specific success logic
      onSuccess(result);

      // Cache sitemap status if available
      if (result.sitemapStatusCode != null) {
        cacheSitemapStatus(site.id, result.sitemapStatusCode);
      }

      // Start cooldown period
      _cooldownService.startCooldown(site.id, minimumCheckInterval);

      _setChecking(site.id, false);
      return true;
    } catch (e) {
      _setError('Failed to check site: $e');
      _setChecking(site.id, false);
      return false;
    }
  }

  /// Delete all monitoring results for a site
  Future<bool> deleteSiteResults(String siteId) async {
    try {
      _clearError();
      await _monitoringService.deleteSiteResults(siteId);
      _resultsBySite.remove(siteId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete monitoring results: $e');
      return false;
    }
  }

  // Helper methods
  void _setChecking(String siteId, bool checking) {
    _isChecking[siteId] = checking;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear error after displaying
  void clearError() {
    _clearError();
  }

  /// Get cached sitemap status for a site
  int? getCachedSitemapStatus(String siteId) {
    return _sitemapStatusCache[siteId];
  }

  /// Cache sitemap status for a site
  void cacheSitemapStatus(String siteId, int? statusCode) {
    _sitemapStatusCache[siteId] = statusCode;
  }

  /// Clear sitemap status cache for a site
  void clearSitemapStatusCache(String siteId) {
    _sitemapStatusCache.remove(siteId);
  }
}

/// Used as a default when no CooldownService is injected into MonitoringProvider.
class _InMemoryCooldownService implements CooldownService {
  final Map<String, DateTime> _nextAllowedAt = {};

  @override
  bool canPerformAction(String siteId) => getTimeUntilNextCheck(siteId) == null;

  @override
  Duration? getTimeUntilNextCheck(String siteId) {
    final now = DateTime.now();

    // Cleanup: Remove ALL expired entries to prevent memory leaks
    _cleanupExpiredEntries();

    final next = _nextAllowedAt[siteId];
    if (next == null || now.isAfter(next)) return null;
    return next.difference(now);
  }

  /// Remove all expired cooldown entries (lazy cleanup)
  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    _nextAllowedAt.removeWhere((_, expiry) => now.isAfter(expiry));
  }

  @override
  void startCooldown(String siteId, Duration duration) {
    _nextAllowedAt[siteId] = DateTime.now().add(duration);
  }

  @override
  Map<String, DateTime> get activeCooldowns => Map.unmodifiable(_nextAllowedAt);

  @override
  void clearCooldown(String siteId) {
    _nextAllowedAt.remove(siteId);
  }

  @override
  void clearAll() {
    _nextAllowedAt.clear();
  }
}
