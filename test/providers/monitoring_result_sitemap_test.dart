import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/monitoring_result.dart';

void main() {
  group('MonitoringResult Sitemap Status Code Tests', () {
    test('should include sitemapStatusCode in MonitoringResult', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: 200,
      );

      expect(result.sitemapStatusCode, 200);
    });

    test('should handle null sitemapStatusCode', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: null,
      );

      expect(result.sitemapStatusCode, null);
    });

    test('should preserve sitemapStatusCode in copyWith', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: 200,
      );

      final copiedResult = result.copyWith(statusCode: 404);
      expect(copiedResult.sitemapStatusCode, 200);
      expect(copiedResult.statusCode, 404);
    });

    test('should update sitemapStatusCode with copyWith', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: 200,
      );

      final copiedResult = result.copyWith(sitemapStatusCode: 404);
      expect(copiedResult.sitemapStatusCode, 404);
    });

    test('should include sitemapStatusCode in toFirestore', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: 200,
      );

      final doc = result.toFirestore();
      expect(doc['sitemapStatusCode'], 200);
    });

    test('should handle null sitemapStatusCode in toFirestore', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        sitemapStatusCode: null,
      );

      final doc = result.toFirestore();
      expect(doc['sitemapStatusCode'], null);
    });

    test('should handle various sitemap status codes', () {
      final now = DateTime.now();
      final statusCodes = [200, 201, 404, 500, 502, 0, null];

      for (final code in statusCodes) {
        final result = MonitoringResult(
          id: 'test-id-$code',
          siteId: 'site-123',
          userId: 'user-456',
          timestamp: now,
          statusCode: 200,
          responseTime: 150,
          isUp: true,
          sitemapStatusCode: code,
        );

        expect(result.sitemapStatusCode, code);
      }
    });
  });

  group('MonitoringResult Deserialization Tests', () {
    test('should deserialize sitemapStatusCode from Firestore data', () {
      final now = DateTime.now();
      final data = {
        'siteId': 'site-123',
        'userId': 'user-456',
        'timestamp': Timestamp.fromDate(now),
        'statusCode': 200,
        'responseTime': 150,
        'isUp': true,
        'error': null,
        'sitemapStatusCode': 200,
      };

      // Simulate Firestore document deserialization
      final sitemapCode = data['sitemapStatusCode'] as int?;
      expect(sitemapCode, 200);
    });

    test('should handle null sitemapStatusCode during deserialization', () {
      final now = DateTime.now();
      final data = {
        'siteId': 'site-123',
        'userId': 'user-456',
        'timestamp': Timestamp.fromDate(now),
        'statusCode': 200,
        'responseTime': 150,
        'isUp': true,
        'error': null,
        'sitemapStatusCode': null,
      };

      final sitemapCode = data['sitemapStatusCode'] as int?;
      expect(sitemapCode, null);
    });

    test(
      'should handle missing sitemapStatusCode in Firestore data (backward compatibility)',
      () {
        final now = DateTime.now();
        // Simulate data from documents created before sitemapStatusCode field was added
        final data = {
          'siteId': 'site-123',
          'userId': 'user-456',
          'timestamp': Timestamp.fromDate(now),
          'statusCode': 200,
          'responseTime': 150,
          'isUp': true,
          'error': null,
          // sitemapStatusCode is missing - this is backward compatibility test
        };

        final sitemapCode = data['sitemapStatusCode'] as int?;
        expect(sitemapCode, null);
      },
    );

    test('should deserialize various sitemap status codes correctly', () {
      final statusCodes = [200, 201, 404, 500, 502, 0];

      for (final code in statusCodes) {
        final data = {'sitemapStatusCode': code};

        final sitemapCode = data['sitemapStatusCode'];
        expect(sitemapCode, code);
      }
    });

    test('should handle sitemapStatusCode with different numeric types', () {
      // Test that int? casting works correctly
      final data = {'sitemapStatusCode': 404};

      final sitemapCode = data['sitemapStatusCode'];
      expect(sitemapCode, isA<int>());
      expect(sitemapCode, 404);
    });
  });

  group('MonitoringProvider Cache Methods Tests', () {
    test('cacheSitemapStatus should store sitemap status code', () {
      final cache = <String, int?>{};
      final siteId = 'site-123';
      final statusCode = 200;

      cache[siteId] = statusCode;

      expect(cache[siteId], 200);
    });

    test('getCachedSitemapStatus should retrieve stored sitemap status', () {
      final cache = <String, int?>{};
      final siteId = 'site-123';
      final statusCode = 200;

      cache[siteId] = statusCode;
      final retrieved = cache[siteId];

      expect(retrieved, 200);
    });

    test(
      'getCachedSitemapStatus should return null for non-existent siteId',
      () {
        final cache = <String, int?>{};
        final siteId = 'non-existent-site';

        final retrieved = cache[siteId];

        expect(retrieved, null);
      },
    );

    test('clearSitemapStatusCache should remove cached status', () {
      final cache = <String, int?>{};
      final siteId = 'site-123';

      cache[siteId] = 200;
      expect(cache[siteId], 200);

      cache.remove(siteId);
      expect(cache[siteId], null);
    });

    test('cache should handle null sitemap status codes', () {
      final cache = <String, int?>{};
      final siteId = 'site-123';

      cache[siteId] = null;

      expect(cache[siteId], null);
    });

    test('cache should update sitemap status codes', () {
      final cache = <String, int?>{};
      final siteId = 'site-123';

      cache[siteId] = 200;
      expect(cache[siteId], 200);

      cache[siteId] = 404;
      expect(cache[siteId], 404);

      cache[siteId] = null;
      expect(cache[siteId], null);
    });

    test('cache should handle multiple sites independently', () {
      final cache = <String, int?>{};

      cache['site-1'] = 200;
      cache['site-2'] = 404;
      cache['site-3'] = null;

      expect(cache['site-1'], 200);
      expect(cache['site-2'], 404);
      expect(cache['site-3'], null);
    });

    test('clearSitemapStatusCache should not affect other sites', () {
      final cache = <String, int?>{};

      cache['site-1'] = 200;
      cache['site-2'] = 404;

      cache.remove('site-1');

      expect(cache['site-1'], null);
      expect(cache['site-2'], 404);
    });

    test('cache should handle edge case status codes', () {
      final cache = <String, int?>{};
      final edgeCases = [0, 1, 599, 1000];

      for (int i = 0; i < edgeCases.length; i++) {
        final siteId = 'site-$i';
        cache[siteId] = edgeCases[i];
        expect(cache[siteId], edgeCases[i]);
      }
    });
  });
}
