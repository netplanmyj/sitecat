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
}
