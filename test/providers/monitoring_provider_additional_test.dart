import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sitecat/models/monitoring_result.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/providers/monitoring_provider.dart';
import 'package:sitecat/services/cooldown_service.dart';

// Reuse existing mocks generated in monitoring_provider_test.mocks.dart
import 'monitoring_provider_test.mocks.dart';

// Minimal fake CooldownService for deterministic tests
class FakeCooldownService implements CooldownService {
  final Map<String, DateTime> _nextAllowed = {};

  @override
  bool canPerformAction(String siteId) => getTimeUntilNextCheck(siteId) == null;

  @override
  Duration? getTimeUntilNextCheck(String siteId) {
    final now = DateTime.now();
    final next = _nextAllowed[siteId];
    if (next == null || now.isAfter(next)) return null;
    return next.difference(now);
  }

  @override
  void startCooldown(String siteId, Duration duration) {
    _nextAllowed[siteId] = DateTime.now().add(duration);
  }

  @override
  Map<String, DateTime> get activeCooldowns => _nextAllowed;

  @override
  void clearCooldown(String siteId) {
    _nextAllowed.remove(siteId);
  }

  @override
  void clearAll() {
    _nextAllowed.clear();
  }

  // Helpers for tests
  void forceCooldown(String siteId, Duration duration) =>
      startCooldown(siteId, duration);
  void clearSite(String siteId) => clearCooldown(siteId);
}

void main() {
  late MockMonitoringService mockMonitoringService;
  late FakeCooldownService cooldown;
  late MonitoringProvider provider;
  late StreamController<List<MonitoringResult>> resultsController;

  Site buildSite({
    String id = 'site-1',
    String userId = 'user-1',
    String url = 'https://example.com',
    String name = 'Example',
  }) {
    final now = DateTime.now();
    return Site(
      id: id,
      userId: userId,
      url: url,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    mockMonitoringService = MockMonitoringService();
    cooldown = FakeCooldownService();
    provider = MonitoringProvider(
      monitoringService: mockMonitoringService,
      cooldownService: cooldown,
    );
    resultsController = StreamController<List<MonitoringResult>>.broadcast();
  });

  tearDown(() async {
    await resultsController.close();
    provider.dispose();
  });

  group('listenToSiteResults', () {
    test('updates results on stream event (empty list ok)', () async {
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => resultsController.stream);

      provider.listenToSiteResults('s1');
      resultsController.add(<MonitoringResult>[]);
      await Future.delayed(Duration.zero);

      expect(provider.getSiteResults('s1'), isA<List<MonitoringResult>>());
      expect(provider.getSiteResults('s1'), isEmpty);
      verify(
        mockMonitoringService.getSiteResults('s1', limit: anyNamed('limit')),
      ).called(1);
    });

    test('sets error on stream error', () async {
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => resultsController.stream);

      provider.listenToSiteResults('s1');
      resultsController.addError('network');
      await Future.delayed(Duration.zero);

      expect(provider.error, contains('Failed to load monitoring results'));
    });

    test(
      'stopListening cancels subscription (no further errors captured)',
      () async {
        when(
          mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
        ).thenAnswer((_) => resultsController.stream);

        provider.listenToSiteResults('s1');
        provider.stopListeningToSiteResults('s1');

        // Emitting an error after stop should not change provider.error
        provider.clearError();
        resultsController.addError('after-stop');
        await Future.delayed(Duration.zero);

        expect(provider.error, isNull);
      },
    );
  });

  group('initialize', () {
    test('demo mode skips subscriptions', () async {
      await provider.initialize(['s1', 's2'], isDemoMode: true);
      verifyNever(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      );
    });

    test('initializeFromSites listens for each site id', () async {
      final fakeSiteProvider = _FakeSiteProvider([
        buildSite(id: 'a'),
        buildSite(id: 'b'),
      ]);
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => const Stream.empty());

      provider.initializeFromSites(fakeSiteProvider);

      verify(
        mockMonitoringService.getSiteResults('a', limit: anyNamed('limit')),
      ).called(1);
      verify(
        mockMonitoringService.getSiteResults('b', limit: anyNamed('limit')),
      ).called(1);
    });
  });

  group('cooldown enforcement', () {
    test(
      'canCheckSite returns true when no cooldown and false during cooldown',
      () {
        final siteId = 's1';
        expect(provider.canCheckSite(siteId), isTrue);

        cooldown.forceCooldown(siteId, const Duration(seconds: 5));
        expect(provider.canCheckSite(siteId), isFalse);
        expect(provider.getTimeUntilNextCheck(siteId), isNotNull);
      },
    );

    test(
      'checkSite blocks when cooldown active and does not call service',
      () async {
        final site = buildSite(id: 's1');
        cooldown.forceCooldown(site.id, const Duration(seconds: 6));

        final ok = await provider.checkSite(site);

        expect(ok, isFalse);
        expect(provider.error, startsWith('Please wait'));
        verifyNever(mockMonitoringService.checkSite(any));
      },
    );

    test(
      'quickCheckSite blocks when cooldown active and does not call service',
      () async {
        final site = buildSite(id: 's1');
        cooldown.forceCooldown(site.id, const Duration(seconds: 6));

        final ok = await provider.quickCheckSite(site);

        expect(ok, isFalse);
        expect(provider.error, startsWith('Please wait'));
        verifyNever(mockMonitoringService.quickCheckSite(any));
      },
    );
  });

  group('deleteSiteResults', () {
    test('returns true on success and calls service', () async {
      when(
        mockMonitoringService.deleteSiteResults('s1'),
      ).thenAnswer((_) async {});

      final ok = await provider.deleteSiteResults('s1');

      expect(ok, isTrue);
      verify(mockMonitoringService.deleteSiteResults('s1')).called(1);
    });

    test('returns false and sets error on failure', () async {
      when(
        mockMonitoringService.deleteSiteResults('s1'),
      ).thenThrow(Exception('boom'));

      final ok = await provider.deleteSiteResults('s1');

      expect(ok, isFalse);
      expect(provider.error, contains('Failed to delete monitoring results'));
    });
  });

  group('sitemap status cache and error clearing', () {
    test('cache, get, and clear sitemap status', () {
      provider.cacheSitemapStatus('s1', 200);
      expect(provider.getCachedSitemapStatus('s1'), 200);

      provider.clearSitemapStatusCache('s1');
      expect(provider.getCachedSitemapStatus('s1'), isNull);
    });

    test('clearError() resets error state', () async {
      // Induce an error via stream
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => resultsController.stream);

      provider.listenToSiteResults('s1');
      resultsController.addError('net');
      await Future.delayed(Duration.zero);
      expect(provider.error, isNotNull);

      provider.clearError();
      expect(provider.error, isNull);
    });
  });
}

class _FakeSiteProvider {
  final List<Site> sites;
  _FakeSiteProvider(this.sites);
}
