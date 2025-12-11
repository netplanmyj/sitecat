import 'dart:async';
import 'package:flutter/material.dart';
import '../models/site.dart';
import '../services/site_service.dart';
import '../services/demo_service.dart';
import '../constants/app_constants.dart';

class SiteProvider extends ChangeNotifier {
  final SiteService _siteService = SiteService();

  // State variables
  List<Site> _sites = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Site>>? _sitesSubscription;
  bool _isDemoMode = false;
  bool _hasLifetimeAccess = false;

  // Getters
  List<Site> get sites => _isDemoMode ? DemoService.getSites() : _sites;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get siteCount => sites.length;
  List<Site> get monitoringSites =>
      sites.where((site) => site.monitoringEnabled).toList();

  /// Check if user can add more sites
  /// Premium users: max 30 sites, Free users: max 3 sites
  bool get canAddSite {
    if (_hasLifetimeAccess) {
      return sites.length < AppConstants.premiumSiteLimit;
    }
    return sites.length < AppConstants.freePlanSiteLimit;
  }

  /// Update premium status (called from UI layer with SubscriptionProvider)
  void setHasLifetimeAccess(bool hasAccess) {
    if (_hasLifetimeAccess != hasAccess) {
      _hasLifetimeAccess = hasAccess;
      notifyListeners();
    }
  }

  // Initialize and start listening to sites
  Future<void> initialize({bool isDemoMode = false}) async {
    _isDemoMode = isDemoMode;
    if (!_isDemoMode) {
      _listenToSites();
    } else {
      // Load demo data
      _setLoading(false);
      notifyListeners();
    }
  }

  // Clean up subscriptions
  @override
  void dispose() {
    _sitesSubscription?.cancel();
    super.dispose();
  }

  // Listen to real-time updates from Firestore
  void _listenToSites() {
    _setLoading(true);
    _sitesSubscription?.cancel();

    _sitesSubscription = _siteService.getUserSites().listen(
      (sites) {
        _sites = sites;
        _setLoading(false);
        _clearError();
        notifyListeners();
      },
      onError: (error) {
        _setError('Failed to load sites: $error');
        _setLoading(false);
      },
    );
  }

  // Create a new site
  Future<bool> createSite({
    required String url,
    required String name,
    String? sitemapUrl,
    bool monitoringEnabled = true,
    int checkInterval = 60,
    List<String>? excludedPaths,
  }) async {
    try {
      _clearError();

      // Check site limit
      if (!canAddSite) {
        final message = _hasLifetimeAccess
            ? AppConstants.premiumSiteLimitReachedMessage
            : AppConstants.siteLimitReachedMessage;
        _setError(message);
        return false;
      }

      // Validate URL format
      if (!await _siteService.validateUrl(url)) {
        _setError('Invalid URL format');
        return false;
      }

      // Check if URL already exists
      if (await _siteService.urlExists(url)) {
        _setError('A site with this URL already exists');
        return false;
      }

      // Create new site
      final now = DateTime.now();
      final site = Site(
        id: '', // Will be set by Firestore
        userId: '', // Will be set by SiteService
        url: url,
        name: name,
        sitemapUrl: sitemapUrl,
        monitoringEnabled: monitoringEnabled,
        checkInterval: checkInterval,
        createdAt: now,
        updatedAt: now,
        excludedPaths: excludedPaths ?? [],
      );

      await _siteService.createSite(site);
      return true;
    } catch (e) {
      _setError('Failed to create site: $e');
      return false;
    }
  }

  // Update an existing site
  Future<bool> updateSite(Site site) async {
    try {
      _clearError();

      // Validate URL format
      if (!await _siteService.validateUrl(site.url)) {
        _setError('Invalid URL format');
        return false;
      }

      // Check if URL already exists (excluding current site)
      if (await _siteService.urlExists(site.url, excludeSiteId: site.id)) {
        _setError('A site with this URL already exists');
        return false;
      }

      // Check if excluded paths have changed
      final originalSite = _sites.firstWhere((s) => s.id == site.id);
      final excludedPathsChanged =
          originalSite.excludedPaths.length != site.excludedPaths.length ||
          !originalSite.excludedPaths.every(
            (path) => site.excludedPaths.contains(path),
          );

      // If excluded paths changed, reset scan index to avoid sitemap URL mismatches
      final updatedSite = site.copyWith(
        updatedAt: DateTime.now(),
        lastScannedPageIndex: excludedPathsChanged
            ? 0
            : site.lastScannedPageIndex,
      );

      await _siteService.updateSite(updatedSite);
      return true;
    } catch (e) {
      _setError('Failed to update site: $e');
      return false;
    }
  }

  // Delete a site
  Future<bool> deleteSite(String siteId) async {
    try {
      _clearError();
      await _siteService.deleteSite(siteId);
      return true;
    } catch (e) {
      _setError('Failed to delete site: $e');
      return false;
    }
  }

  // Toggle monitoring for a site
  Future<bool> toggleMonitoring(String siteId, bool enabled) async {
    try {
      _clearError();
      await _siteService.toggleMonitoring(siteId, enabled);
      return true;
    } catch (e) {
      _setError('Failed to toggle monitoring: $e');
      return false;
    }
  }

  // Get a specific site by ID
  Site? getSite(String siteId) {
    try {
      return _sites.firstWhere((site) => site.id == siteId);
    } catch (e) {
      return null;
    }
  }

  // Search sites
  List<Site> searchSites(String query) {
    if (query.isEmpty) return _sites;

    final searchTerm = query.toLowerCase();
    return _sites.where((site) {
      return site.name.toLowerCase().contains(searchTerm) ||
          site.url.toLowerCase().contains(searchTerm);
    }).toList();
  }

  // Update last checked time for a site
  Future<void> updateLastChecked(String siteId) async {
    try {
      await _siteService.updateLastChecked(siteId, DateTime.now());
    } catch (e) {
      _setError('Failed to update last checked time: $e');
    }
  }

  // Validate site form inputs
  String? validateSiteName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Site name is required';
    }
    if (name.trim().length < 2) {
      return 'Site name must be at least 2 characters';
    }
    if (name.trim().length > 50) {
      return 'Site name must be less than 50 characters';
    }
    return null;
  }

  String? validateSiteUrl(String? url, {String? excludeSiteId}) {
    if (url == null || url.trim().isEmpty) {
      return 'URL is required';
    }

    // Basic URL validation
    try {
      final uri = Uri.parse(url.trim());
      if (!uri.hasScheme) {
        return 'URL must include http:// or https://';
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return 'URL must use http or https protocol';
      }
      if (uri.host.isEmpty) {
        return 'Invalid URL format';
      }
    } catch (e) {
      return 'Invalid URL format';
    }

    return null;
  }

  String? validateCheckInterval(String? interval) {
    if (interval == null || interval.trim().isEmpty) {
      return 'Check interval is required';
    }

    final value = int.tryParse(interval);
    if (value == null) {
      return 'Check interval must be a number';
    }
    if (value < 5) {
      return 'Check interval must be at least 5 minutes';
    }
    if (value > 1440) {
      // 24 hours
      return 'Check interval cannot exceed 24 hours (1440 minutes)';
    }

    return null;
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // Clear error manually (for UI)
  void clearError() {
    _clearError();
  }

  // Get site statistics
  Map<String, int> getSiteStatistics() {
    final total = _sites.length;
    final monitoring = _sites.where((site) => site.monitoringEnabled).length;
    final paused = total - monitoring;

    return {'total': total, 'monitoring': monitoring, 'paused': paused};
  }
}
