import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../utils/url_helper.dart';
import '../../utils/url_encoding_utils.dart';

/// HTTP client for link checking operations
class LinkCheckerHttpClient {
  final http.Client _httpClient;

  LinkCheckerHttpClient(this._httpClient);

  Future<T> _retry<T>(
    Future<T> Function() action, {
    int retries = 1,
    Duration delay = const Duration(milliseconds: 200),
    bool Function(T value)? shouldRetry,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final result = await action();
        if (shouldRetry != null && shouldRetry(result) && attempt < retries) {
          await Future.delayed(delay);
          continue;
        }
        return result;
      } catch (_) {
        if (attempt >= retries) rethrow;
        await Future.delayed(delay);
      }
    }
    throw Exception('_retry: unreachable code');
  }

  /// Check URL with HEAD request before fetching content (with retry on transient failures)
  Future<({int statusCode, String? contentType})> checkUrlHead(
    String url,
  ) async {
    return _retry<({int statusCode, String? contentType})>(
      () async {
        try {
          final response = await _httpClient
              .head(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          final contentType = response.headers['content-type']?.toLowerCase();
          return (statusCode: response.statusCode, contentType: contentType);
        } catch (_) {
          return (statusCode: 0, contentType: null);
        }
      },
      retries: 1,
      shouldRetry: (v) => v.statusCode == 0 || v.statusCode >= 500,
    );
  }

  /// Fetch HTML content from a URL (with HEAD pre-check)
  Future<String?> fetchHtmlContent(String url) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(url);

      // Step 1: HEAD request to check status and content type (retry built-in)
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

      // Step 2: GET request to fetch content (retry on transient failures: network errors and 5xx)
      final response = await _retry<http.Response>(
        () async {
          try {
            return await _httpClient
                .get(Uri.parse(convertedUrl))
                .timeout(const Duration(seconds: 10));
          } catch (_) {
            // Return a dummy response with statusCode 0 to indicate network error
            return http.Response('', 0);
          }
        },
        retries: 1,
        delay: const Duration(milliseconds: 200),
        shouldRetry: (r) => r.statusCode == 0 || r.statusCode >= 500,
      );

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

      // Use HEAD request for efficiency with simple retry
      final response = await _retry<http.Response>(
        () => _httpClient
            .head(Uri.parse(convertedUrl))
            .timeout(const Duration(seconds: 5)),
        retries: 1,
        delay: const Duration(milliseconds: 200),
        shouldRetry: (r) => false, // rely on catch for network retry
      );

      // Consider 404 and 5xx as broken
      if (response.statusCode == 404 || response.statusCode >= 500) {
        return (statusCode: response.statusCode, error: null);
      }

      return null; // Link is OK
    } on http.ClientException catch (e) {
      // Retry once more on network error
      try {
        final convertedUrl = UrlHelper.convertLocalhostForPlatform(
          url.toString(),
        );
        final resp = await _httpClient
            .head(Uri.parse(convertedUrl))
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 404 || resp.statusCode >= 500) {
          return (statusCode: resp.statusCode, error: null);
        }
        return null;
      } catch (_) {
        return (statusCode: 0, error: 'Network error: ${e.message}');
      }
    } catch (e) {
      return (statusCode: 0, error: 'Error: $e');
    }
  }
}
