class ValidationUtils {
  ValidationUtils._();

  /// Accepts only http/https with a non-empty host.
  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final schemeOk = uri.scheme == 'http' || uri.scheme == 'https';
    final hostOk = (uri.host).isNotEmpty;
    return schemeOk && hostOk;
  }
}
