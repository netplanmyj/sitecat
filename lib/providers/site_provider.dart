import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sitecat/models/site.dart';
import '../services/site_service.dart';
import '../services/demo_service.dart';
import '../services/site_transaction_service.dart';
import '../constants/app_constants.dart';
import '../utils/validation.dart';
import 'subscription_provider.dart';

class SiteProvider extends ChangeNotifier {
  SiteProvider({
    SiteService? siteService,
    SiteTransactionService? siteTransactionService,
  }) : _siteService = siteService ?? SiteService(),
       _transactionService = siteTransactionService ?? SiteTransactionService();

  final SiteService _siteService;
  final SiteTransactionService _transactionService;
  final Logger _logger = Logger();

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

  /// Create a new site with transactional limit enforcement (Issue #299)
  Future<bool> createSite({
    required String url,
    required String name,
    String? sitemapUrl,
    List<String> excludedPaths = const [],
    int? checkInterval,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Client-side pre-check for UI responsiveness
      final currentLimit = _hasLifetimeAccess
          ? AppConstants.premiumSiteLimit
          : AppConstants.freePlanSiteLimit;

      if (sites.length >= currentLimit) {
        _error = _hasLifetimeAccess
            ? AppConstants.premiumSiteLimitReachedMessage
            : AppConstants.siteLimitReachedMessage;
        return false;
      }

      // Validate URL format
      if (!await _siteService.validateUrl(url)) {
        _error = 'Invalid URL format';
        return false;
      }

      // Check duplicate URL
      if (await _siteService.urlExists(url)) {
        _error = 'A site with this URL already exists';
        return false;
      }

      try {
        final result = await _transactionService.createSiteTransaction(
          url: url,
          name: name,
          sitemapUrl: sitemapUrl,
          excludedPaths: excludedPaths,
          checkInterval: checkInterval,
        );

        if (result['ok'] == true) {
          _logger.d('Site created via callable');
          return true;
        }
        _error = 'Failed to create site';
        return false;
      } on SiteTransactionException catch (e) {
        _logger.e('Callable error: ${e.code} - ${e.message}', error: e);

        if (e.code == 'failed-precondition' &&
            e.message == 'site-limit-reached') {
          final details = e.details;
          final limit = details?['limit'] as int?;
          _error = (limit == AppConstants.premiumSiteLimit)
              ? AppConstants.premiumSiteLimitReachedMessage
              : AppConstants.siteLimitReachedMessage;
          return false;
        }

        if (e.code == 'unauthenticated') {
          _error = 'Authentication required';
          return false;
        }

        _error = 'Failed to create site: ${e.message}';
        return false;
      } catch (e) {
        _error = 'Failed to create site';
        _logger.e('Failed to create site via callable', error: e);
        return false;
      }
    } catch (e) {
      _error = 'Failed to create site';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
    return Validation.siteName(name);
  }

  String? validateSiteUrl(String? url) {
    return Validation.siteUrl(url);
  }

  String? validateCheckInterval(String? interval) {
    return Validation.checkInterval(interval);
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

  // Add this method to initialize state from SubscriptionProvider
  void initializeFromSubscription(SubscriptionProvider subscriptionProvider) {
    // Sync premium status from SubscriptionProvider
    final isPremium = subscriptionProvider.hasLifetimeAccess;
    setHasLifetimeAccess(isPremium);

    // Start Firestore stream if not started yet (avoid double subscription)
    if (!_isDemoMode && _sitesSubscription == null) {
      _listenToSites();
    }
  }
}
