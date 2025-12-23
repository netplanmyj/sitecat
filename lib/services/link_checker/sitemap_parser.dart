import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../../utils/url_helper.dart';

/// Sitemap parser for extracting URLs from sitemap.xml
class SitemapParser {
  final http.Client _httpClient;
  final int maxPageLimit;

  SitemapParser(this._httpClient, {required this.maxPageLimit});

  /// Fetch URLs from sitemap.xml (supports up to 2 levels of sitemap index)
  Future<List<Uri>> fetchSitemapUrls(
    String sitemapUrl,
    Future<({int statusCode, String? contentType})> Function(String url)
    checkUrlHead,
  ) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(sitemapUrl);

      // Step 1: HEAD request to check status and content type
      final headCheck = await checkUrlHead(convertedUrl);

      if (headCheck.statusCode != 200) {
        throw Exception('Sitemap not accessible: ${headCheck.statusCode}');
      }

      // Verify it's XML content
      final contentType = headCheck.contentType;
      if (contentType != null &&
          !contentType.contains('xml') &&
          !contentType.contains('text/plain')) {
        throw Exception('Invalid sitemap content type: $contentType');
      }

      // Step 2: GET request to fetch sitemap content
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sitemap: ${response.statusCode}');
      }

      // Parse XML
      final document = xml.XmlDocument.parse(response.body);

      // Check if this is a sitemap index (contains <sitemap> elements)
      final sitemapElements = document.findAllElements('sitemap');

      if (sitemapElements.isNotEmpty) {
        // This is a sitemap index - fetch URLs from child sitemaps
        final allUrls = <Uri>[];

        for (final sitemapElement in sitemapElements) {
          final locElement = sitemapElement.findElements('loc').firstOrNull;
          if (locElement != null) {
            final childSitemapUrl = locElement.innerText.trim();
            if (childSitemapUrl.isNotEmpty) {
              try {
                // Fetch URLs from child sitemap (without HEAD check)
                final childUrls = await parseSitemapXml(childSitemapUrl);
                allUrls.addAll(childUrls);

                // Limit total URLs based on user's subscription tier
                if (allUrls.length >= maxPageLimit) {
                  break;
                }
              } catch (e) {
                // Skip this child sitemap if it fails
                continue;
              }
            }
          }
        }

        return allUrls;
      } else {
        // This is a regular sitemap - extract URLs directly from current document
        return extractUrlsFromSitemapDocument(document);
      }
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
  }

  /// Parse a sitemap XML directly from a URL (used for child sitemaps)
  Future<List<Uri>> parseSitemapXml(String sitemapUrl) async {
    try {
      // Convert localhost for Android emulator
      final convertedUrl = UrlHelper.convertLocalhostForPlatform(sitemapUrl);

      // Add delay to avoid overwhelming the server (prioritize server load over speed)
      await Future.delayed(const Duration(milliseconds: 1000));

      // Use shared client instead of creating new one
      final response = await _httpClient
          .get(Uri.parse(convertedUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch sitemap: ${response.statusCode}');
      }

      final document = xml.XmlDocument.parse(response.body);
      return extractUrlsFromSitemapDocument(document);
    } catch (e) {
      throw Exception('Error parsing sitemap: $e');
    }
  }

  /// Extract URLs from a parsed sitemap XML document
  List<Uri> extractUrlsFromSitemapDocument(xml.XmlDocument document) {
    final urlElements = document.findAllElements('url');
    final normalizedUrls =
        <String, Uri>{}; // Use Map to deduplicate by normalized key

    for (final urlElement in urlElements) {
      final locElement = urlElement.findElements('loc').firstOrNull;
      if (locElement != null) {
        final urlString = locElement.innerText.trim();
        if (urlString.isNotEmpty) {
          try {
            final uri = Uri.parse(urlString);
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              // Normalize URL: remove fragment, lowercase scheme/host, and remove trailing slash
              final normalizedUri = normalizeSitemapUrl(uri);
              final normalizedKey = normalizedUri.toString();

              // Store only unique URLs (Map handles deduplication automatically)
              normalizedUrls[normalizedKey] = normalizedUri;
            }
          } catch (e) {
            // Skip invalid URLs
          }
        }
      }
    }

    return normalizedUrls.values.toList();
  }

  /// Normalize sitemap URL by removing fragment, normalizing scheme/host to lowercase, and removing trailing slash
  Uri normalizeSitemapUrl(Uri uri) {
    // Remove fragment (#section)
    final uriWithoutFragment = uri.removeFragment();

    // Normalize scheme and host to lowercase (case-insensitive per RFC 3986)
    final normalizedScheme = uriWithoutFragment.scheme.toLowerCase();
    final normalizedHost = uriWithoutFragment.host.toLowerCase();

    // Remove trailing slash from path (but keep "/" for root)
    String path = uriWithoutFragment.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Reconstruct URI with normalized components
    return uriWithoutFragment.replace(
      scheme: normalizedScheme,
      host: normalizedHost,
      path: path,
    );
  }
}
