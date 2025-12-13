import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sitecat/models/monitoring_result.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/providers/monitoring_provider.dart';
import 'package:sitecat/services/monitoring_service.dart';

import 'monitoring_provider_test.mocks.dart';

@GenerateMocks([MonitoringService])
void main() {
  late MockMonitoringService mockMonitoringService;
  late MonitoringProvider provider;
  late StreamController<List<MonitoringResult>> resultsController;

  Site buildSite({String id = 'site-1', String url = 'https://example.com'}) {
    final now = DateTime.now();
    return Site(
      id: id,
      userId: 'user-1',
      url: url,
      name: 'Example',
      createdAt: now,
      updatedAt: now,
    );
  }

  MonitoringResult buildResult({
    String id = 'res-1',
    String siteId = 'site-1',
    int statusCode = 200,
    int responseTime = 120,
    bool isUp = true,
    int? sitemapStatusCode = 200,
    DateTime? timestamp,
  }) {
    return MonitoringResult(
      id: id,
      siteId: siteId,
      userId: 'user-1',
      timestamp: timestamp ?? DateTime.now(),
      statusCode: statusCode,
      responseTime: responseTime,
      isUp: isUp,
      error: null,
      sitemapStatusCode: sitemapStatusCode,
    );
  }

  setUp(() {
    mockMonitoringService = MockMonitoringService();
    provider = MonitoringProvider(monitoringService: mockMonitoringService);
    resultsController = StreamController<List<MonitoringResult>>.broadcast();
  });

  tearDown(() {
    provider.dispose();
    resultsController.close();
  });

  group('listenToSiteResults', () {
    test('stores latest results for site', () async {
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => resultsController.stream);

      provider.listenToSiteResults('site-1');
      resultsController.add([buildResult(id: 'a'), buildResult(id: 'b')]);
      await Future.delayed(Duration.zero);

      final results = provider.getSiteResults('site-1');
      expect(results, hasLength(2));
      expect(results.first.id, 'a');
    });

    test('initializeFromSites listens for each site', () {
      final sites = [buildSite(id: 'one'), buildSite(id: 'two')];
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => Stream.value([]));

      provider.initializeFromSites(_FakeSiteProvider(sites));

      verify(mockMonitoringService.getSiteResults('one', limit: 50)).called(1);
      verify(mockMonitoringService.getSiteResults('two', limit: 50)).called(1);
    });
  });

  group('checkSite', () {
    test('performs check and caches results', () async {
      final site = buildSite();
      final result = buildResult();
      when(
        mockMonitoringService.checkSite(any),
      ).thenAnswer((_) async => result);

      final success = await provider.checkSite(site);

      expect(success, isTrue);
      expect(provider.isChecking(site.id), isFalse);
      expect(provider.getSiteResults(site.id), isNotEmpty);
      expect(provider.getCachedSitemapStatus(site.id), 200);
      expect(provider.getTimeUntilNextCheck(site.id), isNotNull);
      verify(mockMonitoringService.checkSite(site)).called(1);
    });

    test('blocks checks during cooldown window', () async {
      final site = buildSite();
      final result = buildResult();
      when(
        mockMonitoringService.checkSite(any),
      ).thenAnswer((_) async => result);

      final first = await provider.checkSite(site);
      final second = await provider.checkSite(site);

      expect(first, isTrue);
      expect(second, isFalse);
      expect(provider.error, contains('Please wait'));
      verify(mockMonitoringService.checkSite(site)).called(1);
    });

    test('returns error in demo mode', () async {
      await provider.initialize([], isDemoMode: true);
      final site = buildSite();

      final success = await provider.checkSite(site);

      expect(success, isFalse);
      expect(provider.error, 'Site monitoring is not available in demo mode');
      verifyNever(mockMonitoringService.checkSite(any));
    });
  });

  group('deleteSiteResults', () {
    test('removes cached results and returns true', () async {
      final site = buildSite();
      when(
        mockMonitoringService.checkSite(any),
      ).thenAnswer((_) async => buildResult());
      when(
        mockMonitoringService.deleteSiteResults(any),
      ).thenAnswer((_) async {});

      await provider.checkSite(site);
      final result = await provider.deleteSiteResults(site.id);

      expect(result, isTrue);
      expect(provider.getSiteResults(site.id), isEmpty);
    });
  });

  group('cache helpers', () {
    test('cache and clear sitemap status', () {
      provider.cacheSitemapStatus('site-1', 404);
      expect(provider.getCachedSitemapStatus('site-1'), 404);

      provider.clearSitemapStatusCache('site-1');
      expect(provider.getCachedSitemapStatus('site-1'), isNull);
    });

    test('getAllResults merges and sorts by timestamp', () async {
      when(
        mockMonitoringService.getSiteResults(any, limit: anyNamed('limit')),
      ).thenAnswer((_) => resultsController.stream);

      provider.listenToSiteResults('site-a');
      resultsController.add([
        buildResult(
          id: 'late',
          siteId: 'site-a',
          timestamp: DateTime.now().subtract(Duration(minutes: 1)),
        ),
        buildResult(id: 'latest', siteId: 'site-a', timestamp: DateTime.now()),
      ]);
      await Future.delayed(Duration.zero);

      final all = provider.getAllResults();
      expect(all.first.result.id, 'latest');
      expect(all.last.result.id, 'late');
    });
  });
}

class _FakeSiteProvider {
  _FakeSiteProvider(this.sites);
  final List<Site> sites;
}
