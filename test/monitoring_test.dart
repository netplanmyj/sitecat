import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sitecat/models/monitoring_result.dart';

void main() {
  group('MonitoringResult Model Tests', () {
    test('should create MonitoringResult from valid data', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
        error: null,
      );

      expect(result.id, 'test-id');
      expect(result.siteId, 'site-123');
      expect(result.userId, 'user-456');
      expect(result.timestamp, now);
      expect(result.statusCode, 200);
      expect(result.responseTime, 150);
      expect(result.isUp, true);
      expect(result.error, null);
    });

    test('should create MonitoringResult with error', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 0,
        responseTime: 0,
        isUp: false,
        error: 'Connection timeout',
      );

      expect(result.isUp, false);
      expect(result.error, 'Connection timeout');
    });

    test('should convert MonitoringResult to Firestore document', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 150,
        isUp: true,
      );

      final doc = result.toFirestore();

      expect(doc['siteId'], 'site-123');
      expect(doc['userId'], 'user-456');
      expect(doc['timestamp'], isA<Timestamp>());
      expect(doc['statusCode'], 200);
      expect(doc['responseTime'], 150);
      expect(doc['isUp'], true);
      expect(doc['error'], null);
    });

    test('should convert MonitoringResult with error to Firestore', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 0,
        responseTime: 0,
        isUp: false,
        error: 'Connection failed',
      );

      final doc = result.toFirestore();

      expect(doc['isUp'], false);
      expect(doc['error'], 'Connection failed');
    });

    test('should correctly report up status', () {
      final successResult = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: DateTime.now(),
        statusCode: 200,
        responseTime: 150,
        isUp: true,
      );

      expect(successResult.isUp, true);

      final failureResult = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: DateTime.now(),
        statusCode: 500,
        responseTime: 0,
        isUp: false,
        error: 'Server error',
      );

      expect(failureResult.isUp, false);
    });

    test('should handle different status codes', () {
      final codes = [200, 201, 301, 400, 404, 500, 503];
      
      for (final code in codes) {
        final result = MonitoringResult(
          id: 'test-id',
          siteId: 'site-123',
          userId: 'user-456',
          timestamp: DateTime.now(),
          statusCode: code,
          responseTime: 100,
          isUp: code >= 200 && code < 400,
        );

        expect(result.statusCode, code);
        if (code >= 200 && code < 400) {
          expect(result.isUp, true);
        } else {
          expect(result.isUp, false);
        }
      }
    });

    test('should track response times accurately', () {
      final responseTimes = [50, 100, 200, 500, 1000, 2000];
      
      for (final time in responseTimes) {
        final result = MonitoringResult(
          id: 'test-id',
          siteId: 'site-123',
          userId: 'user-456',
          timestamp: DateTime.now(),
          statusCode: 200,
          responseTime: time,
          isUp: true,
        );

        expect(result.responseTime, time);
      }
    });

    test('should preserve timestamp precision', () {
      final now = DateTime.now();
      final result = MonitoringResult(
        id: 'test-id',
        siteId: 'site-123',
        userId: 'user-456',
        timestamp: now,
        statusCode: 200,
        responseTime: 100,
        isUp: true,
      );

      expect(result.timestamp.year, now.year);
      expect(result.timestamp.month, now.month);
      expect(result.timestamp.day, now.day);
      expect(result.timestamp.hour, now.hour);
      expect(result.timestamp.minute, now.minute);
    });
  });
}
