import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/constants/app_constants.dart';

void main() {
  group('Site Limit Constants Tests', () {
    test('site limit constant is set correctly', () {
      expect(AppConstants.freePlanSiteLimit, equals(1));
      expect(AppConstants.siteLimitMessage, isNotEmpty);
      expect(AppConstants.siteLimitReachedMessage, isNotEmpty);
    });

    test('site limit message contains the limit number', () {
      final message = AppConstants.siteLimitMessage;
      expect(message, contains('1'));
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
}
