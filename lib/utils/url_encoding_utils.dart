import 'dart:convert';

/// Utility class for handling URL encoding issues, particularly mojibake
class UrlEncodingUtils {
  /// Fix mojibake in URLs caused by double-encoding
  /// Detects Japanese double-encoding patterns and attempts recovery
  static String fixMojibakeUrl(String url) {
    try {
      // Decode URL first
      final decoded = Uri.decodeFull(url);

      // Check for mojibake patterns (Japanese double-encoding)
      if (!containsMojibake(decoded)) {
        return url; // No mojibake detected, return original
      }

      // Attempt recovery: treat decoded string as Latin-1, re-decode as UTF-8
      final latin1Bytes = latin1.encode(decoded);
      final utf8String = utf8.decode(latin1Bytes, allowMalformed: true);

      // Validate recovery (no replacement character �)
      if (utf8String.contains('�')) {
        return url; // Recovery failed, return original
      }

      // Recovery successful, re-encode properly
      return Uri.encodeFull(utf8String);
    } catch (e) {
      return url; // Error during processing, return original
    }
  }

  /// Check if a decoded URL contains mojibake patterns
  ///
  /// Detects Japanese double-encoding patterns:
  /// - Pattern 1: Â followed by 0x80-0xBF (C2 byte sequences from UTF-8 continuation bytes)
  /// - Pattern 2: é followed by control characters 0x80-0x9F (E9 from 開発)
  static bool containsMojibake(String decoded) {
    final patterns = [
      RegExp('Â[\u0080-\u00BF]Â[\u0080-\u00BF]'), // C2 sequences
      RegExp('é[\u0080-\u009F][\u0080-\u009F]'), // é + control chars
    ];

    return patterns.any((pattern) => pattern.hasMatch(decoded));
  }
}
