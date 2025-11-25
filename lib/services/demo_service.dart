import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/models/monitoring_result.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/models/demo_data.dart';

/// Service for managing demo mode data
class DemoService {
  static const String _demoModeKey = 'demo_mode_enabled';
  static const String _demoInitializedKey = 'demo_initialized';

  /// Check if demo mode is enabled
  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoModeKey) ?? false;
  }

  /// Enable demo mode
  static Future<void> enableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, true);

    // Initialize demo data on first use
    final initialized = prefs.getBool(_demoInitializedKey) ?? false;
    if (!initialized) {
      await _initializeDemoData();
      await prefs.setBool(_demoInitializedKey, true);
    }
  }

  /// Disable demo mode
  static Future<void> disableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, false);
  }

  /// Initialize demo data (called once on first demo mode use)
  static Future<void> _initializeDemoData() async {
    // Demo data is generated on-the-fly via DemoData class
    // No need to persist it in SharedPreferences
  }

  /// Get demo sites
  static List<Site> getSites() {
    return DemoData.getDemoSites();
  }

  /// Get demo monitoring results for a site
  static List<MonitoringResult> getMonitoringResults(String siteId) {
    return DemoData.getDemoMonitoringResults(siteId);
  }

  /// Get demo broken links for a site
  static List<BrokenLink> getBrokenLinks(String siteId) {
    return DemoData.getDemoBrokenLinks(siteId);
  }

  /// Get demo link check results for a site
  static List<LinkCheckResult> getLinkCheckResults(String siteId) {
    return DemoData.getDemoLinkCheckResults(siteId);
  }

  /// Get a specific demo site by ID
  static Site? getSiteById(String siteId) {
    try {
      return DemoData.getDemoSites().firstWhere((site) => site.id == siteId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all demo data
  static Future<void> clearDemoData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoModeKey);
    await prefs.remove(_demoInitializedKey);
  }
}
