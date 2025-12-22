import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/cooldown_service.dart';

void main() {
  late DefaultCooldownService cooldownService;

  setUp(() {
    cooldownService = DefaultCooldownService();
  });

  group('CooldownService', () {
    group('canPerformAction', () {
      test('returns true when no cooldown exists', () {
        expect(cooldownService.canPerformAction('site-1'), isTrue);
      });

      test('returns false during active cooldown', () async {
        cooldownService.startCooldown('site-1', const Duration(seconds: 5));
        expect(cooldownService.canPerformAction('site-1'), isFalse);
      });

      test('returns true after cooldown expires', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 100),
        );
        expect(cooldownService.canPerformAction('site-1'), isFalse);

        await Future.delayed(const Duration(milliseconds: 150));

        expect(cooldownService.canPerformAction('site-1'), isTrue);
      });

      test('removes expired entry when checking', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 50),
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // canPerformAction should trigger cleanup
        cooldownService.canPerformAction('site-1');

        expect(cooldownService.activeCooldowns, isEmpty);
      });
    });

    group('getTimeUntilNextCheck', () {
      test('returns null when no cooldown exists', () {
        expect(cooldownService.getTimeUntilNextCheck('site-1'), isNull);
      });

      test('returns positive duration during active cooldown', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        final remaining = cooldownService.getTimeUntilNextCheck('site-1');

        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, lessThanOrEqualTo(10));
        expect(remaining.inSeconds, greaterThan(0));
      });

      test('returns null after cooldown expires', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 100),
        );
        await Future.delayed(const Duration(milliseconds: 150));

        expect(cooldownService.getTimeUntilNextCheck('site-1'), isNull);
      });

      test('removes expired entry (lazy cleanup)', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 50),
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // getTimeUntilNextCheck triggers cleanup for expired entries
        cooldownService.getTimeUntilNextCheck('site-1');

        expect(cooldownService.activeCooldowns, isEmpty);
      });

      test('calculates remaining time accurately', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        final remaining = cooldownService.getTimeUntilNextCheck('site-1');

        expect(remaining, isNotNull);
        // Should be close to 10 seconds (allow 1s margin for execution time)
        expect(remaining!.inSeconds, greaterThanOrEqualTo(8));
      });
    });

    group('startCooldown', () {
      test('sets cooldown for a site', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));

        expect(cooldownService.canPerformAction('site-1'), isFalse);
      });

      test('overwrites existing cooldown', () async {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        final firstCheck = cooldownService.getTimeUntilNextCheck('site-1');

        // Wait a bit then overwrite with shorter cooldown
        await Future.delayed(const Duration(milliseconds: 100));
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 50),
        );

        final secondCheck = cooldownService.getTimeUntilNextCheck('site-1');
        expect(
          secondCheck!.inMilliseconds,
          lessThan(firstCheck!.inMilliseconds),
        );
      });

      test('allows independent cooldowns per site', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        cooldownService.startCooldown('site-2', const Duration(seconds: 5));

        expect(cooldownService.canPerformAction('site-1'), isFalse);
        expect(cooldownService.canPerformAction('site-2'), isFalse);
      });
    });

    group('activeCooldowns', () {
      test('returns empty map when no cooldowns', () {
        expect(cooldownService.activeCooldowns, isEmpty);
      });

      test('returns unmodifiable map with active cooldowns', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        cooldownService.startCooldown('site-2', const Duration(seconds: 5));

        final active = cooldownService.activeCooldowns;
        expect(active.length, 2);
        expect(active.containsKey('site-1'), isTrue);
        expect(active.containsKey('site-2'), isTrue);
      });

      test('returns unmodifiable map (prevents external mutation)', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));

        final active = cooldownService.activeCooldowns;
        expect(() => active.clear(), throwsUnsupportedError);
      });

      test('does not include expired cooldowns', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 50),
        );
        cooldownService.startCooldown('site-2', const Duration(seconds: 10));

        await Future.delayed(const Duration(milliseconds: 100));

        // Trigger cleanup for expired entry
        cooldownService.getTimeUntilNextCheck('site-1');

        final active = cooldownService.activeCooldowns;
        expect(active.length, 1);
        expect(active.containsKey('site-2'), isTrue);
      });
    });

    group('clearCooldown', () {
      test('removes cooldown for specified site', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        expect(cooldownService.canPerformAction('site-1'), isFalse);

        cooldownService.clearCooldown('site-1');

        expect(cooldownService.canPerformAction('site-1'), isTrue);
      });

      test('does not affect other sites', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        cooldownService.startCooldown('site-2', const Duration(seconds: 10));

        cooldownService.clearCooldown('site-1');

        expect(cooldownService.canPerformAction('site-1'), isTrue);
        expect(cooldownService.canPerformAction('site-2'), isFalse);
      });

      test('is safe to call on non-existent site', () {
        expect(() => cooldownService.clearCooldown('site-1'), returnsNormally);
      });
    });

    group('clearAll', () {
      test('removes all cooldowns', () {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        cooldownService.startCooldown('site-2', const Duration(seconds: 10));
        cooldownService.startCooldown('site-3', const Duration(seconds: 10));

        cooldownService.clearAll();

        expect(cooldownService.activeCooldowns, isEmpty);
        expect(cooldownService.canPerformAction('site-1'), isTrue);
        expect(cooldownService.canPerformAction('site-2'), isTrue);
        expect(cooldownService.canPerformAction('site-3'), isTrue);
      });

      test('is safe to call on empty service', () {
        expect(() => cooldownService.clearAll(), returnsNormally);
      });
    });

    group('concurrent operations', () {
      test('handles multiple sites independently', () async {
        cooldownService.startCooldown('site-1', const Duration(seconds: 10));
        cooldownService.startCooldown(
          'site-2',
          const Duration(milliseconds: 50),
        );
        cooldownService.startCooldown('site-3', const Duration(seconds: 10));

        expect(cooldownService.canPerformAction('site-1'), isFalse);
        expect(cooldownService.canPerformAction('site-2'), isFalse);
        expect(cooldownService.canPerformAction('site-3'), isFalse);

        await Future.delayed(const Duration(milliseconds: 100));

        // site-2 should expire, others active
        expect(cooldownService.canPerformAction('site-1'), isFalse);
        expect(cooldownService.canPerformAction('site-2'), isTrue);
        expect(cooldownService.canPerformAction('site-3'), isFalse);
      });

      test('supports rapid start/clear cycles', () {
        for (int i = 0; i < 10; i++) {
          cooldownService.startCooldown('site-1', const Duration(seconds: 1));
          expect(cooldownService.canPerformAction('site-1'), isFalse);

          cooldownService.clearCooldown('site-1');
          expect(cooldownService.canPerformAction('site-1'), isTrue);
        }
      });
    });

    group('memory management (lazy cleanup)', () {
      test('cleans up expired entries on getTimeUntilNextCheck', () async {
        for (int i = 0; i < 5; i++) {
          cooldownService.startCooldown(
            'site-$i',
            const Duration(milliseconds: 50),
          );
        }

        await Future.delayed(const Duration(milliseconds: 100));

        // Before cleanup
        expect(cooldownService.activeCooldowns.length, 5);

        // Trigger cleanup by checking one
        cooldownService.getTimeUntilNextCheck('site-0');

        // After lazy cleanup, all expired entries should be removed
        expect(cooldownService.activeCooldowns, isEmpty);
      });

      test('does not prevent valid check during cleanup', () async {
        cooldownService.startCooldown(
          'site-1',
          const Duration(milliseconds: 50),
        );
        cooldownService.startCooldown('site-2', const Duration(seconds: 10));

        await Future.delayed(const Duration(milliseconds: 100));

        // Check expired site - triggers cleanup
        cooldownService.getTimeUntilNextCheck('site-1');

        // site-2 should still be in cooldown (not cleared by cleanup)
        expect(cooldownService.canPerformAction('site-2'), isFalse);
      });
    });

    group('edge cases', () {
      test('handles zero duration cooldown', () {
        cooldownService.startCooldown('site-1', Duration.zero);

        // Should immediately be expired
        expect(cooldownService.canPerformAction('site-1'), isTrue);
      });

      test('handles very long cooldown duration', () {
        cooldownService.startCooldown('site-1', const Duration(days: 1));
        final remaining = cooldownService.getTimeUntilNextCheck('site-1');

        expect(remaining, isNotNull);
        expect(remaining!.inHours, greaterThan(20));
      });

      test('handles multiple rapid calls to same methods', () {
        for (int i = 0; i < 100; i++) {
          cooldownService.canPerformAction('site-1');
        }

        expect(cooldownService.canPerformAction('site-1'), isTrue);
      });
    });
  });
}
