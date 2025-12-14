import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/utils/validation.dart';

void main() {
  group('Validation.siteName', () {
    test('returns error for empty', () {
      expect(Validation.siteName(''), isNotNull);
    });
    test('returns error for too short', () {
      expect(Validation.siteName('a'), isNotNull);
    });
    test('returns error for too long', () {
      expect(Validation.siteName('a' * 51), isNotNull);
    });
    test('returns null for valid', () {
      expect(Validation.siteName('My Site'), isNull);
    });
  });

  group('Validation.siteUrl', () {
    test('requires scheme', () {
      expect(Validation.siteUrl('example.com'), isNotNull);
    });
    test('invalid scheme', () {
      expect(Validation.siteUrl('ftp://example.com'), isNotNull);
    });
    test('requires host', () {
      expect(Validation.siteUrl('https://'), isNotNull);
    });
    test('valid http', () {
      expect(Validation.siteUrl('http://example.com'), isNull);
    });
    test('valid https', () {
      expect(Validation.siteUrl('https://example.com'), isNull);
    });
  });

  group('Validation.sitemapInput', () {
    test('null/empty passes', () {
      expect(Validation.sitemapInput(null), isNull);
      expect(Validation.sitemapInput(''), isNull);
    });
    test('relative path passes', () {
      expect(Validation.sitemapInput('sitemap.xml'), isNull);
      expect(Validation.sitemapInput('/sitemap.xml'), isNull);
    });
    test('invalid full URL fails', () {
      expect(Validation.sitemapInput('https://'), isNotNull);
    });
    test('valid full URL passes', () {
      expect(
        Validation.sitemapInput('https://example.com/sitemap.xml'),
        isNull,
      );
    });
  });

  group('Validation.checkInterval', () {
    test('requires value', () {
      expect(Validation.checkInterval(null), isNotNull);
      expect(Validation.checkInterval(''), isNotNull);
    });
    test('numeric only', () {
      expect(Validation.checkInterval('abc'), isNotNull);
    });
    test('lower bound', () {
      expect(Validation.checkInterval('4'), isNotNull);
      expect(Validation.checkInterval('5'), isNull);
    });
    test('upper bound', () {
      expect(Validation.checkInterval('1440'), isNull);
      expect(Validation.checkInterval('1441'), isNotNull);
    });
  });
}
