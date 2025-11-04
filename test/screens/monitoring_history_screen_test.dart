import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/monitoring_result.dart';

void main() {
  group('MonitoringHistoryScreen Statistics Calculations', () {
    test('calculates uptime correctly with all successful checks', () {
      final results = [
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
      ];

      final successfulChecks = results.where((r) => r.isUp).length;
      final uptime = (successfulChecks / results.length) * 100;

      expect(uptime, 100.0);
      expect(successfulChecks, 5);
    });

    test('calculates uptime correctly with mixed results', () {
      final results = [
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: false), // 1 failure
        _createMonitoringResult(isUp: false), // 1 failure
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
      ];

      final successfulChecks = results.where((r) => r.isUp).length;
      final uptime = (successfulChecks / results.length) * 100;

      expect(uptime, 80.0); // 8 out of 10 = 80%
      expect(successfulChecks, 8);
    });

    test('calculates uptime correctly with all failed checks', () {
      final results = [
        _createMonitoringResult(isUp: false),
        _createMonitoringResult(isUp: false),
        _createMonitoringResult(isUp: false),
      ];

      final successfulChecks = results.where((r) => r.isUp).length;
      final uptime = (successfulChecks / results.length) * 100;

      expect(uptime, 0.0);
      expect(successfulChecks, 0);
    });

    test('handles empty results gracefully', () {
      final results = <MonitoringResult>[];

      final successfulChecks = results.where((r) => r.isUp).length;
      final uptime = results.isNotEmpty
          ? (successfulChecks / results.length) * 100
          : 0.0;

      expect(uptime, 0.0);
      expect(successfulChecks, 0);
    });

    test('calculates average response time correctly', () {
      final results = [
        _createMonitoringResult(responseTime: 100),
        _createMonitoringResult(responseTime: 200),
        _createMonitoringResult(responseTime: 300),
        _createMonitoringResult(responseTime: 400),
        _createMonitoringResult(responseTime: 500),
      ];

      final avgResponseTime =
          results.map((r) => r.responseTime).reduce((a, b) => a + b) /
          results.length;

      expect(avgResponseTime, 300.0);
    });

    test('calculates average response time with varying values', () {
      final results = [
        _createMonitoringResult(responseTime: 50),
        _createMonitoringResult(responseTime: 150),
        _createMonitoringResult(responseTime: 250),
      ];

      final avgResponseTime =
          results.map((r) => r.responseTime).reduce((a, b) => a + b) /
          results.length;

      expect(avgResponseTime.round(), 150);
    });

    test('handles empty results for average response time', () {
      final results = <MonitoringResult>[];

      final avgResponseTime = results.isNotEmpty
          ? results.map((r) => r.responseTime).reduce((a, b) => a + b) /
                results.length
          : 0;

      expect(avgResponseTime, 0);
    });

    test('counts successful and failed checks correctly', () {
      final results = [
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: false),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: false),
        _createMonitoringResult(isUp: false),
      ];

      final successfulChecks = results.where((r) => r.isUp).length;
      final failedChecks = results.length - successfulChecks;

      expect(successfulChecks, 3);
      expect(failedChecks, 3);
    });

    test('formats uptime percentage to one decimal place', () {
      final results = [
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: true),
        _createMonitoringResult(isUp: false),
      ];

      final successfulChecks = results.where((r) => r.isUp).length;
      final uptime = (successfulChecks / results.length) * 100;
      final uptimeString = uptime.toStringAsFixed(1);

      expect(uptimeString, '66.7');
    });
  });

  group('Time Formatting', () {
    test('formats time as "Just now" for recent timestamps', () {
      final now = DateTime.now();
      final recent = now.subtract(const Duration(seconds: 30));

      final formatted = _formatRelativeTime(recent);

      expect(formatted, 'Just now');
    });

    test('formats time as "Xm ago" for minutes', () {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

      final formatted = _formatRelativeTime(fiveMinutesAgo);

      expect(formatted, '5m ago');
    });

    test('formats time as "Xh ago" for hours', () {
      final now = DateTime.now();
      final twoHoursAgo = now.subtract(const Duration(hours: 2));

      final formatted = _formatRelativeTime(twoHoursAgo);

      expect(formatted, '2h ago');
    });

    test('formats time as "Xd ago" for recent days', () {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      final formatted = _formatRelativeTime(threeDaysAgo);

      expect(formatted, '3d ago');
    });

    test('formats time as date for older timestamps', () {
      final now = DateTime.now();
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      final formatted = _formatRelativeTime(tenDaysAgo);

      // Should return MM/DD HH:MM format
      expect(formatted, contains('/'));
      expect(formatted, contains(':'));
    });

    test('handles edge case: exactly 1 minute ago', () {
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

      final formatted = _formatRelativeTime(oneMinuteAgo);

      expect(formatted, '1m ago');
    });

    test('handles edge case: exactly 1 hour ago', () {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      final formatted = _formatRelativeTime(oneHourAgo);

      expect(formatted, '1h ago');
    });

    test('handles edge case: exactly 1 day ago', () {
      final now = DateTime.now();
      final oneDayAgo = now.subtract(const Duration(days: 1));

      final formatted = _formatRelativeTime(oneDayAgo);

      expect(formatted, '1d ago');
    });

    test('handles edge case: 59 minutes ago (still shows minutes)', () {
      final now = DateTime.now();
      final fiftyNineMinutesAgo = now.subtract(const Duration(minutes: 59));

      final formatted = _formatRelativeTime(fiftyNineMinutesAgo);

      expect(formatted, '59m ago');
    });

    test('handles edge case: 23 hours ago (still shows hours)', () {
      final now = DateTime.now();
      final twentyThreeHoursAgo = now.subtract(const Duration(hours: 23));

      final formatted = _formatRelativeTime(twentyThreeHoursAgo);

      expect(formatted, '23h ago');
    });
  });
}

// Helper function to create MonitoringResult for testing
MonitoringResult _createMonitoringResult({
  bool isUp = true,
  int responseTime = 100,
  int statusCode = 200,
}) {
  return MonitoringResult(
    id: 'test-${DateTime.now().millisecondsSinceEpoch}',
    siteId: 'test-site',
    userId: 'test-user',
    timestamp: DateTime.now(),
    statusCode: statusCode,
    responseTime: responseTime,
    isUp: isUp,
  );
}

// Helper function to format relative time (extracted from screen logic)
String _formatRelativeTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
