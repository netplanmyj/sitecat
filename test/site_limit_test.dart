import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/constants/app_constants.dart';

void main() {
  group('Site Limit Constants Tests', () {
    test('site limit constant is set correctly', () {
      expect(AppConstants.freePlanSiteLimit, equals(3));
      expect(AppConstants.siteLimitMessage, isNotEmpty);
      expect(AppConstants.siteLimitReachedMessage, isNotEmpty);
    });

    test('site limit message contains the limit number', () {
      final message = AppConstants.siteLimitMessage;
      expect(message, contains('3'));
      expect(message, contains('個'));
    });

    test('site limit reached message has proper content', () {
      final errorMessage = AppConstants.siteLimitReachedMessage;
      expect(errorMessage, contains('上限'));
      expect(errorMessage, contains('削除'));
    });

    test('check interval constants are defined correctly', () {
      expect(AppConstants.minCheckInterval, equals(5));
      expect(AppConstants.maxCheckInterval, equals(1440));
      expect(AppConstants.defaultCheckInterval, equals(60));
    });

    test('min check interval is less than max', () {
      expect(
        AppConstants.minCheckInterval < AppConstants.maxCheckInterval,
        isTrue,
      );
    });

    test('default check interval is within valid range', () {
      expect(
        AppConstants.defaultCheckInterval >= AppConstants.minCheckInterval,
        isTrue,
      );
      expect(
        AppConstants.defaultCheckInterval <= AppConstants.maxCheckInterval,
        isTrue,
      );
    });

    test('free plan limit is positive', () {
      expect(AppConstants.freePlanSiteLimit > 0, isTrue);
    });

    test('all limit messages are non-empty', () {
      expect(AppConstants.siteLimitMessage.isNotEmpty, isTrue);
      expect(AppConstants.siteLimitReachedMessage.isNotEmpty, isTrue);
    });
  });

  group('Page and History Limit Constants', () {
    test('premium page limit constant is correct', () {
      // Assert: Premium plan allows 1000 pages
      expect(AppConstants.premiumPlanPageLimit, 1000);
    });

    test('free page limit constant is correct', () {
      // Assert: Free plan allows 200 pages
      expect(AppConstants.freePlanPageLimit, 200);
    });

    test('premium history limit constant is correct', () {
      // Assert: Premium plan keeps 50 history items
      expect(AppConstants.premiumHistoryLimit, 50);
    });

    test('free history limit constant is correct', () {
      // Assert: Free plan keeps 10 history items
      expect(AppConstants.freePlanHistoryLimit, 10);
    });

    test('premium page limit is greater than free limit', () {
      // Assert: Premium users can scan more pages
      expect(
        AppConstants.premiumPlanPageLimit,
        greaterThan(AppConstants.freePlanPageLimit),
      );
    });

    test('premium history limit is greater than free limit', () {
      // Assert: Premium users can keep more history
      expect(
        AppConstants.premiumHistoryLimit,
        greaterThan(AppConstants.freePlanHistoryLimit),
      );
    });

    test('all page limits are positive', () {
      expect(AppConstants.freePlanPageLimit > 0, isTrue);
      expect(AppConstants.premiumPlanPageLimit > 0, isTrue);
    });

    test('all history limits are positive', () {
      expect(AppConstants.freePlanHistoryLimit > 0, isTrue);
      expect(AppConstants.premiumHistoryLimit > 0, isTrue);
    });
  });
}
