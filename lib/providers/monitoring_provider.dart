import 'dart:async';
import 'package:flutter/material.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../services/monitoring_service.dart';

class MonitoringProvider extends ChangeNotifier {
  final MonitoringService _monitoringService = MonitoringService();

  // Minimum interval between checks (1 minute for debugging)
  static const Duration minimumCheckInterval = Duration(minutes: 1);

  // State variables
  final Map<String, List<MonitoringResult>> _resultsBySite = {};
  final Map<String, bool> _isChecking = {};
  final Map<String, DateTime> _lastCheckTime = {};
  String? _error;
  Map<String, StreamSubscription<List<MonitoringResult>>>? _subscriptions;

  // Getters
  String? get error => _error;

  /// Get monitoring results for a specific site
  List<MonitoringResult> getSiteResults(String siteId) {
    return _resultsBySite[siteId] ?? [];
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

  /// Perform a manual check on a site
  Future<bool> checkSite(Site site) async {
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

      final result = await _monitoringService.checkSite(site);

      // Update local cache
      final existingResults = _resultsBySite[site.id] ?? [];
      _resultsBySite[site.id] = [result, ...existingResults];

      // Record check time
      _lastCheckTime[site.id] = DateTime.now();

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
}
