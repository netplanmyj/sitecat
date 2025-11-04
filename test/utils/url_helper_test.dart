import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/utils/url_helper.dart';

void main() {
  group('UrlHelper', () {
    group('isLocalhost', () {
      test('identifies localhost correctly', () {
        expect(UrlHelper.isLocalhost('http://localhost:8080'), true);
        expect(UrlHelper.isLocalhost('https://localhost'), true);
        expect(UrlHelper.isLocalhost('http://LOCALHOST:3000'), true);
      });

      test('identifies 127.0.0.1 correctly', () {
        expect(UrlHelper.isLocalhost('http://127.0.0.1:8080'), true);
        expect(UrlHelper.isLocalhost('https://127.0.0.1'), true);
      });

      test('identifies 10.0.2.2 (Android emulator) correctly', () {
        expect(UrlHelper.isLocalhost('http://10.0.2.2:8080'), true);
        expect(UrlHelper.isLocalhost('https://10.0.2.2'), true);
      });

      test('identifies non-localhost URLs correctly', () {
        expect(UrlHelper.isLocalhost('https://example.com'), false);
        expect(UrlHelper.isLocalhost('http://192.168.1.1'), false);
        expect(UrlHelper.isLocalhost('https://google.com'), false);
      });

      test('handles invalid URLs gracefully', () {
        expect(UrlHelper.isLocalhost('not a url'), false);
        expect(UrlHelper.isLocalhost(''), false);
      });
    });

    group('normalizeUrl', () {
      test('converts 10.0.2.2 to localhost', () {
        expect(
          UrlHelper.normalizeUrl('http://10.0.2.2:8080/path'),
          'http://localhost:8080/path',
        );
        expect(
          UrlHelper.normalizeUrl('https://10.0.2.2/test'),
          'https://localhost/test',
        );
      });

      test('keeps localhost as-is', () {
        expect(
          UrlHelper.normalizeUrl('http://localhost:8080'),
          'http://localhost:8080',
        );
      });

      test('keeps regular URLs unchanged', () {
        expect(
          UrlHelper.normalizeUrl('https://example.com/path'),
          'https://example.com/path',
        );
      });

      test('handles invalid URLs gracefully', () {
        expect(UrlHelper.normalizeUrl('invalid'), 'invalid');
      });
    });

    // Note: convertLocalhostForPlatform tests would require platform mocking
    // which is complex in unit tests. These are better suited for integration tests.
    group('convertLocalhostForPlatform (basic validation)', () {
      test('returns valid URL for localhost input', () {
        final result = UrlHelper.convertLocalhostForPlatform(
          'http://localhost:8080',
        );
        expect(Uri.tryParse(result), isNotNull);
      });

      test('returns valid URL for regular URL input', () {
        const url = 'https://example.com/path';
        final result = UrlHelper.convertLocalhostForPlatform(url);
        expect(result, url);
      });

      test('handles invalid URLs gracefully', () {
        const invalidUrl = 'not a url';
        final result = UrlHelper.convertLocalhostForPlatform(invalidUrl);
        expect(result, invalidUrl);
      });
    });
  });
}
