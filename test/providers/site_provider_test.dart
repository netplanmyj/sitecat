import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sitecat/constants/app_constants.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/providers/site_provider.dart';
import 'package:sitecat/services/site_service.dart';

import 'site_provider_test.mocks.dart';

@GenerateMocks([SiteService])
void main() {
  late MockSiteService mockSiteService;
  late SiteProvider provider;
  late StreamController<List<Site>> sitesController;

  Site buildSite({
    String id = 'site-1',
    String userId = 'user-1', // Default value for userId
    String url = 'https://example.com',
    String name = 'Example',
    List<String> excludedPaths = const [],
    int lastScannedPageIndex = 0,
  }) {
    final now = DateTime.now();
    return Site(
      id: id,
      userId: userId, // Ensure userId is passed
      url: url,
      name: name,
      createdAt: now,
      updatedAt: now,
      excludedPaths: excludedPaths,
      lastScannedPageIndex: lastScannedPageIndex,
    );
  }

  void stubSiteCreationSuccess() {
    when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
    when(mockSiteService.urlExists(any)).thenAnswer((_) async => false);
    when(mockSiteService.createSite(any)).thenAnswer((_) async => 'new-id');
  }

  void stubSiteUpdateSuccess() {
    when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
    when(
      mockSiteService.urlExists(any, excludeSiteId: anyNamed('excludeSiteId')),
    ).thenAnswer((_) async => false);
    when(mockSiteService.updateSite(any)).thenAnswer((_) async => true);
  }

  void seedSites(int count) {
    provider.sites.addAll(
      List.generate(
        count,
        (index) => buildSite(
          id: 'seed-$index',
          userId: 'user-1',
          url: 'https://seed$index.com',
          name: 'Seed $index',
        ),
      ),
    );
  }

  setUp(() {
    mockSiteService = MockSiteService();
    provider = SiteProvider(siteService: mockSiteService);
    sitesController = StreamController<List<Site>>.broadcast();

    when(
      mockSiteService.getUserSites(),
    ).thenAnswer((_) => sitesController.stream);
  });

  tearDown(() {
    provider.dispose();
    sitesController.close();
  });

  group('initialize', () {
    test('loads sites and clears loading/error', () async {
      await provider.initialize();

      sitesController.add([buildSite()]);
      await Future.delayed(Duration.zero);

      expect(provider.isLoading, false);
      expect(provider.sites, hasLength(1));
      expect(provider.error, isNull);
    });

    test('handles stream error gracefully', () async {
      await provider.initialize();

      sitesController.addError('network');
      await Future.delayed(Duration.zero);

      expect(provider.error, contains('Failed to load sites'));
      expect(provider.isLoading, false);
    });
  });

  group('createSite', () {
    setUp(() async {
      await provider.initialize();
    });

    test('returns false when site limit reached (free)', () async {
      sitesController.add([
        buildSite(id: '1', userId: 'user-1'),
        buildSite(id: '2', userId: 'user-1'),
        buildSite(id: '3', userId: 'user-1'),
      ]);
      await Future.delayed(Duration.zero);

      final result = await provider.createSite(
        url: 'https://new.com',
        name: 'New',
      );

      expect(result, isFalse);
      expect(provider.error, AppConstants.siteLimitReachedMessage);
      verifyNever(mockSiteService.createSite(any));
    });

    test('rejects invalid url', () async {
      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => false);

      final result = await provider.createSite(url: 'invalid-url', name: 'Bad');

      expect(result, isFalse);
      expect(provider.error, 'Invalid URL format');
      verifyNever(mockSiteService.createSite(any));
    });

    test('rejects duplicate url', () async {
      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
      when(mockSiteService.urlExists(any)).thenAnswer((_) async => true);

      final result = await provider.createSite(
        url: 'https://dup.com',
        name: 'Dup',
      );

      expect(result, isFalse);
      expect(provider.error, 'A site with this URL already exists');
      verifyNever(mockSiteService.createSite(any));
    });

    test('creates site successfully', () async {
      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
      when(mockSiteService.urlExists(any)).thenAnswer((_) async => false);
      when(mockSiteService.createSite(any)).thenAnswer((_) async => 'new-id');

      final result = await provider.createSite(
        url: 'https://good.com',
        name: 'Good',
        sitemapUrl: '/sitemap.xml',
        excludedPaths: ['private'],
        checkInterval: 15,
      );

      expect(result, isTrue);
      expect(provider.error, isNull);
      verify(mockSiteService.createSite(any)).called(1);
    });
  });

  group('updateSite', () {
    setUp(() async {
      await provider.initialize();
      final original = buildSite(
        id: 'site-1',
        userId: 'user-1',
        excludedPaths: ['old'],
        lastScannedPageIndex: 5,
      );
      sitesController.add([original]);
      await Future.delayed(Duration.zero);
    });

    test('rejects invalid url', () async {
      final site = buildSite(url: 'bad-url');
      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => false);

      final result = await provider.updateSite(site);

      expect(result, isFalse);
      expect(provider.error, 'Invalid URL format');
      verifyNever(mockSiteService.updateSite(any));
    });

    test('rejects duplicate url', () async {
      final site = buildSite(url: 'https://dup.com');
      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
      when(
        mockSiteService.urlExists(
          any,
          excludeSiteId: anyNamed('excludeSiteId'),
        ),
      ).thenAnswer((_) async => true);

      final result = await provider.updateSite(site);

      expect(result, isFalse);
      expect(provider.error, 'A site with this URL already exists');
      verifyNever(mockSiteService.updateSite(any));
    });

    test('resets lastScannedPageIndex when excludedPaths changed', () async {
      final updatedSite = buildSite(
        id: 'site-1',
        userId: 'user-1',
        excludedPaths: ['old', 'new'],
        lastScannedPageIndex: 10,
      );

      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
      when(
        mockSiteService.urlExists(
          any,
          excludeSiteId: anyNamed('excludeSiteId'),
        ),
      ).thenAnswer((_) async => false);
      Site? saved;
      when(mockSiteService.updateSite(any)).thenAnswer((invocation) async {
        saved = invocation.positionalArguments[0] as Site;
      });

      final result = await provider.updateSite(updatedSite);

      expect(result, isTrue);
      expect(saved?.lastScannedPageIndex, 0);
      expect(saved?.excludedPaths, ['old', 'new']);
    });

    test('keeps lastScannedPageIndex when excludedPaths unchanged', () async {
      final updatedSite = buildSite(
        id: 'site-1',
        userId: 'user-1',
        excludedPaths: ['old'],
        lastScannedPageIndex: 10,
      );

      when(mockSiteService.validateUrl(any)).thenAnswer((_) async => true);
      when(
        mockSiteService.urlExists(
          any,
          excludeSiteId: anyNamed('excludeSiteId'),
        ),
      ).thenAnswer((_) async => false);
      Site? saved;
      when(mockSiteService.updateSite(any)).thenAnswer((invocation) async {
        saved = invocation.positionalArguments[0] as Site;
      });

      final result = await provider.updateSite(updatedSite);

      expect(result, isTrue);
      expect(saved?.lastScannedPageIndex, 10);
      expect(saved?.excludedPaths, ['old']);
    });
  });

  group('deletion and monitoring toggle', () {
    test('deleteSite returns true', () async {
      when(mockSiteService.deleteSite(any)).thenAnswer((_) async {});

      final result = await provider.deleteSite('site-1');

      expect(result, isTrue);
    });

    test('toggleMonitoring returns true', () async {
      when(mockSiteService.toggleMonitoring(any, any)).thenAnswer((_) async {});

      final result = await provider.toggleMonitoring('site-1', true);

      expect(result, isTrue);
    });
  });

  group('utility getters', () {
    setUp(() async {
      await provider.initialize();
      sitesController.add([
        buildSite(
          id: '1',
          userId: 'user-1',
          name: 'Alpha',
          url: 'https://alpha.com',
        ),
        buildSite(
          id: '2',
          userId: 'user-1',
          name: 'Beta',
          url: 'https://beta.com',
        ),
      ]);
      await Future.delayed(Duration.zero);
    });

    test('getSite returns matching site', () {
      final site = provider.getSite('1');
      expect(site?.id, '1');
    });

    test('getSite returns null when missing', () {
      final site = provider.getSite('missing');
      expect(site, isNull);
    });

    test('searchSites filters by name or url', () {
      final results = provider.searchSites('beta');
      expect(results, hasLength(1));
      expect(results.first.id, '2');
    });

    test('getSiteStatistics counts monitoring flags', () {
      final stats = provider.getSiteStatistics();
      expect(stats['total'], 2);
      expect(stats['monitoring'], 2);
      expect(stats['paused'], 0);
    });
  });

  group('SiteProvider Tests', () {
    test('initialize() sets demo mode correctly', () async {
      await provider.initialize(isDemoMode: true);
      expect(provider.isLoading, false);
      expect(provider.sites, isNotEmpty); // Demo sites loaded
    });

    test('createSite() enforces site limit for free users', () async {
      when(mockSiteService.getUserSites()).thenAnswer((_) => Stream.value([]));
      stubSiteCreationSuccess();
      provider.setHasLifetimeAccess(false); // Free user
      seedSites(AppConstants.freePlanSiteLimit);

      final result = await provider.createSite(
        url: 'https://exceed-limit.com',
        name: 'Exceed Limit',
      );
      expect(result, false);
      expect(provider.error, AppConstants.siteLimitReachedMessage);
    });

    test('createSite() allows up to premium limit for premium users', () async {
      when(mockSiteService.getUserSites()).thenAnswer((_) => Stream.value([]));
      stubSiteCreationSuccess();
      provider.setHasLifetimeAccess(true); // Premium user
      seedSites(AppConstants.premiumSiteLimit);

      final result = await provider.createSite(
        url: 'https://exceed-limit.com',
        name: 'Exceed Limit',
      );
      expect(result, false);
      expect(provider.error, AppConstants.premiumSiteLimitReachedMessage);
    });

    test('updateSite() validates URL and updates site', () async {
      final site = Site(
        id: '1',
        url: 'https://example.com',
        name: 'Example',
        userId: 'user-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.initialize();
      provider.sites.add(site);

      stubSiteUpdateSuccess();

      final updatedSite = site.copyWith(name: 'Updated Example');
      final result = await provider.updateSite(updatedSite);

      expect(result, true);
      verify(mockSiteService.updateSite(updatedSite)).called(1);
    });

    test('deleteSite() removes site successfully', () async {
      final siteId = '1';
      when(mockSiteService.deleteSite(siteId)).thenAnswer((_) async => true);

      final result = await provider.deleteSite(siteId);

      expect(result, true);
      verify(mockSiteService.deleteSite(siteId)).called(1);
    });

    test('toggleMonitoring() toggles monitoring state', () async {
      final siteId = '1';
      when(
        mockSiteService.toggleMonitoring(siteId, true),
      ).thenAnswer((_) async => true);

      final result = await provider.toggleMonitoring(siteId, true);

      expect(result, true);
      verify(mockSiteService.toggleMonitoring(siteId, true)).called(1);
    });

    test('searchSites() filters sites by query', () {
      provider.initialize();
      provider.sites.addAll([
        Site(
          id: '1',
          url: 'https://example.com',
          name: 'Example',
          userId: 'user-1',
          createdAt: DateTime.parse('2025-12-20T12:00:00Z'),
          updatedAt: DateTime.parse('2025-12-20T12:00:00Z'),
        ),
        Site(
          id: '2',
          url: 'https://test.com',
          name: 'Test',
          userId: 'user-1',
          createdAt: DateTime.parse('2025-12-20T12:00:00Z'),
          updatedAt: DateTime.parse('2025-12-20T12:00:00Z'),
        ),
      ]);

      final results = provider.searchSites('example');
      expect(results.length, 1);
      expect(results.first.name, 'Example');
    });

    test('getSiteStatistics() returns correct counts', () {
      provider.initialize();
      provider.sites.addAll([
        Site(
          id: '1',
          url: 'https://example.com',
          name: 'Example',
          monitoringEnabled: true,
          userId: 'user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Site(
          id: '2',
          url: 'https://test.com',
          name: 'Test',
          monitoringEnabled: false,
          userId: 'user-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final stats = provider.getSiteStatistics();
      expect(stats['total'], 2);
      expect(stats['monitoring'], 1);
      expect(stats['paused'], 1);
    });
  });
}
