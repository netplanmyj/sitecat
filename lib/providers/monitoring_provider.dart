import 'dart:async';
import 'package:flutter/material.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../services/monitoring_service.dart';

class MonitoringProvider extends ChangeNotifier {
  final MonitoringService _monitoringService = MonitoringService();

  // State variables
  final Map<String, List<MonitoringResult>> _resultsBySite = {};
  final Map<String, bool> _isChecking = {};
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

  /// Perform a manual check on a site
  Future<bool> checkSite(Site site) async {
    try {
      _clearError();
      _setChecking(site.id, true);

      final result = await _monitoringService.checkSite(site);

      // Update local cache
      final existingResults = _resultsBySite[site.id] ?? [];
      _resultsBySite[site.id] = [result, ...existingResults];

      _setChecking(site.id, false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to check site: $e');
      _setChecking(site.id, false);
      return false;
    }
  }

  /// Calculate uptime percentage for a site
  Future<double> getUptime(
    String siteId, {
    Duration period = const Duration(days: 7),
  }) async {
    try {
      return await _monitoringService.calculateUptime(siteId, period: period);
    } catch (e) {
      _setError('Failed to calculate uptime: $e');
      return 0.0;
    }
  }

  /// Calculate average response time for a site
  Future<int> getAverageResponseTime(
    String siteId, {
    Duration period = const Duration(days: 7),
  }) async {
    try {
      return await _monitoringService.calculateAverageResponseTime(
        siteId,
        period: period,
      );
    } catch (e) {
      _setError('Failed to calculate average response time: $e');
      return 0;
    }
  }

  /// Get monitoring statistics for a site
  Future<MonitoringStats> getStats(String siteId) async {
    try {
      final uptime = await getUptime(siteId);
      final avgResponseTime = await getAverageResponseTime(siteId);
      final latestResult = getLatestResult(siteId);
      final totalChecks = _resultsBySite[siteId]?.length ?? 0;

      return MonitoringStats(
        uptime: uptime,
        averageResponseTime: avgResponseTime,
        totalChecks: totalChecks,
        isCurrentlyUp: latestResult?.isUp ?? false,
        lastChecked: latestResult?.timestamp,
      );
    } catch (e) {
      _setError('Failed to get statistics: $e');
      return MonitoringStats(
        uptime: 0,
        averageResponseTime: 0,
        totalChecks: 0,
        isCurrentlyUp: false,
      );
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

/// Monitoring statistics model
class MonitoringStats {
  final double uptime;
  final int averageResponseTime;
  final int totalChecks;
  final bool isCurrentlyUp;
  final DateTime? lastChecked;

  MonitoringStats({
    required this.uptime,
    required this.averageResponseTime,
    required this.totalChecks,
    required this.isCurrentlyUp,
    this.lastChecked,
  });

  String get uptimeDisplay => '${uptime.toStringAsFixed(1)}%';

  String get averageResponseTimeDisplay {
    if (averageResponseTime < 1000) {
      return '${averageResponseTime}ms';
    }
    return '${(averageResponseTime / 1000).toStringAsFixed(2)}s';
  }

  String get statusText => isCurrentlyUp ? 'Online' : 'Offline';

  Color get statusColor => isCurrentlyUp ? Colors.green : Colors.red;
}
