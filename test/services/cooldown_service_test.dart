import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/cooldown_service.dart';

void main() {
  late CooldownService service;

  setUp(() {
    service = CooldownService();
  });

  group('CooldownService', () {
    test('allows action when no cooldown is active', () {
      expect(service.canPerformAction('site-1'), isTrue);
      expect(service.getTimeUntilNextCheck('site-1'), isNull);
    });

    test('blocks action during cooldown period', () {
      service.startCooldown('site-1', const Duration(seconds: 10));

      expect(service.canPerformAction('site-1'), isFalse);
      expect(service.getTimeUntilNextCheck('site-1'), isNotNull);
    });

    test('allows action after cooldown expires', () async {
      service.startCooldown('site-1', const Duration(milliseconds: 100));

      expect(service.canPerformAction('site-1'), isFalse);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(service.canPerformAction('site-1'), isTrue);
      expect(service.getTimeUntilNextCheck('site-1'), isNull);
    });

    test('returns correct remaining time', () {
      service.startCooldown('site-1', const Duration(seconds: 10));

      final remaining = service.getTimeUntilNextCheck('site-1');
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThan(8));
      expect(remaining.inSeconds, lessThanOrEqualTo(10));
    });

    test('tracks multiple sites independently', () {
      service.startCooldown('site-1', const Duration(seconds: 10));
      service.startCooldown('site-2', const Duration(seconds: 20));

      expect(service.canPerformAction('site-1'), isFalse);
      expect(service.canPerformAction('site-2'), isFalse);
      expect(service.canPerformAction('site-3'), isTrue);

      final remaining1 = service.getTimeUntilNextCheck('site-1');
      final remaining2 = service.getTimeUntilNextCheck('site-2');

      expect(remaining1, isNotNull);
      expect(remaining2, isNotNull);
      expect(remaining2!.inSeconds, greaterThan(remaining1!.inSeconds));
    });

    test('clearCooldown removes cooldown for specific site', () {
      service.startCooldown('site-1', const Duration(seconds: 10));
      service.startCooldown('site-2', const Duration(seconds: 10));

      service.clearCooldown('site-1');

      expect(service.canPerformAction('site-1'), isTrue);
      expect(service.canPerformAction('site-2'), isFalse);
    });

    test('clearAll removes all cooldowns', () {
      service.startCooldown('site-1', const Duration(seconds: 10));
      service.startCooldown('site-2', const Duration(seconds: 10));
      service.startCooldown('site-3', const Duration(seconds: 10));

      service.clearAll();

      expect(service.canPerformAction('site-1'), isTrue);
      expect(service.canPerformAction('site-2'), isTrue);
      expect(service.canPerformAction('site-3'), isTrue);
      expect(service.activeCooldowns, isEmpty);
    });

    test('activeCooldowns returns current state', () {
      expect(service.activeCooldowns, isEmpty);

      service.startCooldown('site-1', const Duration(seconds: 10));
      expect(service.activeCooldowns, hasLength(1));
      expect(service.activeCooldowns.containsKey('site-1'), isTrue);

      service.startCooldown('site-2', const Duration(seconds: 10));
      expect(service.activeCooldowns, hasLength(2));
    });

    test('overwrites existing cooldown when restarted', () {
      service.startCooldown('site-1', const Duration(seconds: 5));
      final first = service.getTimeUntilNextCheck('site-1');

      service.startCooldown('site-1', const Duration(seconds: 20));
      final second = service.getTimeUntilNextCheck('site-1');

      expect(second!.inSeconds, greaterThan(first!.inSeconds));
    });

    test('handles zero duration cooldown', () {
      service.startCooldown('site-1', Duration.zero);

      // Should allow immediately since duration is zero
      expect(service.canPerformAction('site-1'), isTrue);
    });
  });
}
