import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/site.dart';

void main() {
  group('Site Model Tests', () {
    test('Site model creation and validation', () {
      final now = DateTime.now();
      final site = Site(
        id: 'test_site_123',
        userId: 'test_user_123',
        url: 'https://example.com',
        name: 'Test Site',
        monitoringEnabled: true,
        checkInterval: 60,
        createdAt: now,
      );

      expect(site.id, equals('test_site_123'));
      expect(site.userId, equals('test_user_123'));
      expect(site.url, equals('https://example.com'));
      expect(site.name, equals('Test Site'));
      expect(site.monitoringEnabled, isTrue);
      expect(site.checkInterval, equals(60));
      expect(site.createdAt, equals(now));
      expect(site.lastChecked, isNull);
    });

    test('Site model URL validation', () {
      final site1 = Site(
        id: 'test1',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Valid HTTPS Site',
        createdAt: DateTime.now(),
      );

      final site2 = Site(
        id: 'test2',
        userId: 'user1',
        url: 'http://example.com',
        name: 'Valid HTTP Site',
        createdAt: DateTime.now(),
      );

      final site3 = Site(
        id: 'test3',
        userId: 'user1',
        url: 'invalid-url',
        name: 'Invalid Site',
        createdAt: DateTime.now(),
      );

      expect(site1.isValidUrl, isTrue);
      expect(site2.isValidUrl, isTrue);
      expect(site3.isValidUrl, isFalse);
    });

    test('Site model display URL formatting', () {
      final site = Site(
        id: 'test',
        userId: 'user1',
        url: 'https://www.example.com/path/to/page',
        name: 'Test Site',
        createdAt: DateTime.now(),
      );

      expect(site.displayUrl, equals('www.example.com'));
    });

    test('Site model copyWith functionality', () {
      final originalSite = Site(
        id: 'test',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Original Site',
        monitoringEnabled: false,
        checkInterval: 30,
        createdAt: DateTime.now(),
      );

      final updatedSite = originalSite.copyWith(
        name: 'Updated Site',
        monitoringEnabled: true,
        checkInterval: 60,
      );

      expect(updatedSite.id, equals(originalSite.id));
      expect(updatedSite.userId, equals(originalSite.userId));
      expect(updatedSite.url, equals(originalSite.url));
      expect(updatedSite.name, equals('Updated Site'));
      expect(updatedSite.monitoringEnabled, isTrue);
      expect(updatedSite.checkInterval, equals(60));
    });

    test('Site model time display formatting', () {
      final now = DateTime.now();

      // Test lastCheckedDisplay
      final site1 = Site(
        id: 'test1',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        createdAt: now,
        lastChecked: null,
      );
      expect(site1.lastCheckedDisplay, equals('Never'));

      final site2 = Site(
        id: 'test2',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        createdAt: now,
        lastChecked: now.subtract(const Duration(minutes: 30)),
      );
      expect(site2.lastCheckedDisplay, equals('30m ago'));

      // Test checkIntervalDisplay
      final site3 = Site(
        id: 'test3',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        checkInterval: 60,
        createdAt: now,
      );
      expect(site3.checkIntervalDisplay, equals('1h'));

      final site4 = Site(
        id: 'test4',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        checkInterval: 90,
        createdAt: now,
      );
      expect(site4.checkIntervalDisplay, equals('1h 30m'));
    });
  });

  group('Site Provider Validation Tests', () {
    late MockSiteProvider siteProvider;

    setUp(() {
      siteProvider = MockSiteProvider();
    });

    test('Site name validation', () {
      expect(
        siteProvider.validateSiteName(null),
        equals('Site name is required'),
      );
      expect(
        siteProvider.validateSiteName(''),
        equals('Site name is required'),
      );
      expect(
        siteProvider.validateSiteName('A'),
        equals('Site name must be at least 2 characters'),
      );
      expect(
        siteProvider.validateSiteName('A' * 51),
        equals('Site name must be less than 50 characters'),
      );
      expect(siteProvider.validateSiteName('Valid Site Name'), isNull);
    });

    test('URL validation', () {
      expect(siteProvider.validateSiteUrl(null), equals('URL is required'));
      expect(siteProvider.validateSiteUrl(''), equals('URL is required'));
      expect(
        siteProvider.validateSiteUrl('invalid-url'),
        equals('URL must include http:// or https://'),
      );
      expect(
        siteProvider.validateSiteUrl('ftp://example.com'),
        equals('URL must use http or https protocol'),
      );
      expect(siteProvider.validateSiteUrl('https://example.com'), isNull);
    });

    test('Check interval validation', () {
      expect(
        siteProvider.validateCheckInterval(null),
        equals('Check interval is required'),
      );
      expect(
        siteProvider.validateCheckInterval(''),
        equals('Check interval is required'),
      );
      expect(
        siteProvider.validateCheckInterval('abc'),
        equals('Check interval must be a number'),
      );
      expect(
        siteProvider.validateCheckInterval('3'),
        equals('Check interval must be at least 5 minutes'),
      );
      expect(
        siteProvider.validateCheckInterval('1500'),
        equals('Check interval cannot exceed 24 hours (1440 minutes)'),
      );
      expect(siteProvider.validateCheckInterval('60'), isNull);
    });
  });

  group('Site Registration Logic Tests', () {
    test('Site creation with valid data', () {
      final now = DateTime.now();
      final site = Site(
        id: 'new_site',
        userId: 'user123',
        url: 'https://newsite.com',
        name: 'New Site',
        monitoringEnabled: true,
        checkInterval: 30,
        createdAt: now,
      );

      expect(site.isValidUrl, isTrue);
      expect(site.name, isNotEmpty);
      expect(site.checkInterval, greaterThanOrEqualTo(5));
      expect(site.checkInterval, lessThanOrEqualTo(1440));
    });

    test('Site registration validation rules', () {
      final site1 = Site(
        id: 'test1',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        checkInterval: 5,
        createdAt: DateTime.now(),
      );
      expect(site1.checkInterval, equals(5));

      final site2 = Site(
        id: 'test2',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Test Site',
        checkInterval: 1440,
        createdAt: DateTime.now(),
      );
      expect(site2.checkInterval, equals(1440));
    });

    test('Site equality and hash code', () {
      final site1 = Site(
        id: 'same_id',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Site 1',
        createdAt: DateTime.now(),
      );

      final site2 = Site(
        id: 'same_id',
        userId: 'user2',
        url: 'https://different.com',
        name: 'Site 2',
        createdAt: DateTime.now(),
      );

      final site3 = Site(
        id: 'different_id',
        userId: 'user1',
        url: 'https://example.com',
        name: 'Site 1',
        createdAt: DateTime.now(),
      );

      expect(site1, equals(site2));
      expect(site1.hashCode, equals(site2.hashCode));
      expect(site1, isNot(equals(site3)));
    });
  });
}

// Mock SiteProvider for testing without Firebase
class MockSiteProvider {
  // Direct validation methods without Firebase dependencies
  String? validateSiteName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Site name is required';
    }
    if (name.trim().length < 2) {
      return 'Site name must be at least 2 characters';
    }
    if (name.trim().length > 50) {
      return 'Site name must be less than 50 characters';
    }
    return null;
  }

  String? validateSiteUrl(String? url, {String? excludeSiteId}) {
    if (url == null || url.trim().isEmpty) {
      return 'URL is required';
    }

    // Basic URL validation
    try {
      final uri = Uri.parse(url.trim());
      if (!uri.hasScheme) {
        return 'URL must include http:// or https://';
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return 'URL must use http or https protocol';
      }
      if (uri.host.isEmpty) {
        return 'Invalid URL format';
      }
    } catch (e) {
      return 'Invalid URL format';
    }

    return null;
  }

  String? validateCheckInterval(String? interval) {
    if (interval == null || interval.trim().isEmpty) {
      return 'Check interval is required';
    }

    final value = int.tryParse(interval);
    if (value == null) {
      return 'Check interval must be a number';
    }
    if (value < 5) {
      return 'Check interval must be at least 5 minutes';
    }
    if (value > 1440) {
      // 24 hours
      return 'Check interval cannot exceed 24 hours (1440 minutes)';
    }

    return null;
  }
}
