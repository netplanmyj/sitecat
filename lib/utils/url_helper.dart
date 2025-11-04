import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Utility class for handling URLs, especially for development environments
class UrlHelper {
  /// Convert localhost URLs to platform-specific addresses
  ///
  /// On Android emulator:
  /// - localhost -> 10.0.2.2
  /// - 127.0.0.1 -> 10.0.2.2
  ///
  /// On iOS simulator and other platforms:
  /// - No conversion (localhost works as-is)
  static String convertLocalhostForPlatform(String url) {
    // Web doesn't need conversion
    if (kIsWeb) return url;

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Only convert on Android
      if (Platform.isAndroid) {
        // Convert localhost and 127.0.0.1 to Android emulator's special IP
        if (host == 'localhost' || host == '127.0.0.1') {
          return uri.replace(host: '10.0.2.2').toString();
        }
      }

      return url;
    } catch (e) {
      // If URL parsing fails, return as-is
      return url;
    }
  }

  /// Normalize a URL for comparison (convert 10.0.2.2 back to localhost)
  /// This is useful for comparing URLs across platforms
  static String normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Convert Android emulator IP back to localhost
      if (host == '10.0.2.2') {
        return uri.replace(host: 'localhost').toString();
      }

      return url;
    } catch (e) {
      return url;
    }
  }

  /// Check if a URL is a localhost URL
  static bool isLocalhost(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
    } catch (e) {
      return false;
    }
  }
}
