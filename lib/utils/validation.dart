// No Flutter imports needed for pure validation helpers

/// Centralized validation utilities for forms and inputs
class Validation {
  Validation._();

  /// Validate a human-friendly site name
  static String? siteName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Site name is required';
    }
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      return 'Site name must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Site name must be less than 50 characters';
    }
    return null;
  }

  /// Validate a website URL. Requires http/https with host.
  static String? siteUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'URL is required';
    }
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
    } catch (_) {
      return 'Invalid URL format';
    }
    return null;
  }

  /// Validate sitemap input. Accepts empty, relative paths, or full URLs.
  static String? sitemapInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // optional
    }

    final v = value.trim();
    // Allow relative paths like "sitemap.xml" or "/sitemap.xml"
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      return null;
    }

    final uri = Uri.tryParse(v);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  /// Validate monitoring check interval in minutes (5..1440)
  static String? checkInterval(String? interval) {
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
      return 'Check interval cannot exceed 24 hours (1440 minutes)';
    }
    return null;
  }
}
