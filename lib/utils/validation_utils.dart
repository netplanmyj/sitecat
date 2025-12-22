import 'validation.dart';

class ValidationUtils {
  ValidationUtils._();

  /// Returns `true` if [url] passes the existing [Validation.siteUrl] check.
  ///
  /// This is a thin wrapper around [Validation.siteUrl] to avoid duplicating
  /// URL validation logic. It assumes [Validation.siteUrl] returns `null`
  /// when the value is valid and a non-null error message otherwise.
  static bool isValidUrl(String url) {
    return Validation.siteUrl(url) == null;
  }
}
