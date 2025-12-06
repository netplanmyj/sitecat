import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../utils/url_helper.dart';
import '../../utils/url_encoding_utils.dart';

/// HTTP client for link checking operations
class LinkCheckerHttpClient {
  final http.Client _httpClient;

  LinkCheckerHttpClient(this._httpClient);

  /// Check URL with HEAD request before fetching content
  Future<({int statusCode, String? contentType})> checkUrlHead(
    String url,
  ) async {
    try {
      final response = await _httpClient
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      final contentType = response.headers['content-type']?.toLowerCase();
      return (statusCode: response.statusCode, contentType: contentType);
    } catch (e) {
      return (statusCode: 0, contentType: null);
    }
  }

  /// Fetch HTML content from a URL (with HEAD pre-check)
  Future<String?> fetchHtmlContent(String url) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(url);

      // Step 1: HEAD request to check status and content type
      final headCheck = await checkUrlHead(convertedUrl);

      // Skip if not OK status
      if (headCheck.statusCode != 200) {
        return null;
      }

      // Skip if not HTML content
      final contentType = headCheck.contentType;
      if (contentType != null && !contentType.contains('text/html')) {
        return null;
      }

      // Step 2: GET request to fetch content
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract links from HTML content
  List<Uri> extractLinks(String htmlContent, Uri baseUrl) {
    final document = html_parser.parse(htmlContent);
    final linkElements = document.querySelectorAll('a[href]');

    final links = <Uri>[];
    for (final element in linkElements) {
      final href = element.attributes['href'];
      if (href == null || href.isEmpty) continue;

      // Skip anchor links and javascript links
      if (href.startsWith('#') || href.startsWith('javascript:')) continue;

      try {
        // Resolve relative URLs
        final uri = baseUrl.resolve(href);
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          // Fix mojibake in URL before adding to list
          final fixedUrl = UrlEncodingUtils.fixMojibakeUrl(uri.toString());
          links.add(Uri.parse(fixedUrl));
        }
      } catch (e) {
        // Invalid URL, skip
      }
    }

    // Remove duplicates
    return links.toSet().toList();
  }

  /// Check if a link is broken
  Future<({int statusCode, String? error})?> checkLink(Uri url) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(
        url.toString(),
      );

      // Use HEAD request for efficiency
      final response = await _httpClient
          .head(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 5));

      // Consider 404 and 5xx as broken
      if (response.statusCode == 404 || response.statusCode >= 500) {
        return (statusCode: response.statusCode, error: null);
      }

      return null; // Link is OK
    } on http.ClientException catch (e) {
      return (statusCode: 0, error: 'Network error: ${e.message}');
    } catch (e) {
      return (statusCode: 0, error: 'Error: $e');
    }
  }
}
