import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/models/monitoring_result.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/models/demo_data.dart';

/// Service for managing demo mode data
class DemoService {
  static const String _demoModeKey = 'demo_mode_enabled';

  /// Check if demo mode is enabled
  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoModeKey) ?? false;
  }

  /// Enable demo mode
  static Future<void> enableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, true);
  }

  /// Disable demo mode
  static Future<void> disableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, false);
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
  }
}
