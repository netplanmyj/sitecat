/// Utility functions for URL handling
class UrlUtils {
  /// Check if a link check result has a URL mismatch
  /// Returns true if the checked URL differs from the current site URL
  static bool hasUrlMismatch(String checkedUrl, String currentUrl) {
    return _normalizeUrl(checkedUrl) != _normalizeUrl(currentUrl);
  }

  /// Normalize URL for comparison
  /// Removes protocol, www prefix, and trailing slash
  static String _normalizeUrl(String url) {
    String normalized = url.toLowerCase().trim();

    // Remove protocol (http:// or https://)
    normalized = normalized.replaceFirst(RegExp(r'^https?://'), '');

    // Remove www. prefix
    normalized = normalized.replaceFirst(RegExp(r'^www\.'), '');

    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}
