# Phase 1 Issue Templates

Ready-to-use GitHub issue descriptions for Phase 1 test coverage tasks.

---

## Issue #264: Add comprehensive tests for SiteProvider

**Labels:** `testing`, `P0-critical`, `phase-1`  
**Milestone:** v1.0.9  
**Effort:** 4-6 hours

### Description

Add comprehensive test coverage for `SiteProvider` to ensure safe refactoring and prevent regressions in site management logic.

### Current State
- **Test Coverage:** 0%
- **Lines:** ~200
- **Complexity:** High (CRUD operations, excluded paths, index reset)
- **Risk:** 🔴 CRITICAL - Data loss/corruption if bugs introduced

### Goals
- Achieve 90%+ test coverage for SiteProvider
- Test all public methods
- Cover edge cases and error scenarios
- Enable safe refactoring in future phases

### Test Scenarios

#### 1. loadSites()
- ✅ Successfully loads sites from Firestore
- ✅ Handles empty collection
- ✅ Handles Firebase errors
- ✅ Notifies listeners correctly

#### 2. addSite()
- ✅ Creates new site successfully
- ✅ Enforces site limit (free: 5, premium: 30)
- ✅ Validates required fields
- ✅ Handles duplicate URLs
- ✅ Sets correct timestamps

#### 3. updateSite()
- ✅ Updates site successfully
- ✅ Detects excluded paths changes
- ✅ Resets lastScannedPageIndex when excluded paths change (#258 fix)
- ✅ Preserves unchanged fields
- ✅ Handles non-existent site

#### 4. deleteSite()
- ✅ Deletes site successfully
- ✅ Removes from local cache
- ✅ Handles non-existent site
- ✅ Cleans up related data (verify cascade)

#### 5. Premium Logic
- ✅ Enforces free tier limit (5 sites)
- ✅ Enforces premium tier limit (30 sites)
- ✅ Premium status updates correctly

### Acceptance Criteria
- [ ] New file: `test/providers/site_provider_test.dart`
- [ ] 20+ tests added
- [ ] All tests passing (green)
- [ ] Edge cases covered
- [ ] Mock Firestore properly
- [ ] Code review approved

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:sitecat/providers/site_provider.dart';
import 'package:sitecat/models/site.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth fakeAuth;
  late SiteProvider provider;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = MockFirebaseAuth(signedIn: true);
    provider = SiteProvider(
      firestore: fakeFirestore,
      auth: fakeAuth,
    );
  });

  group('SiteProvider - loadSites', () {
    test('loads sites successfully from Firestore', () async {
      // Arrange
      final userId = fakeAuth.currentUser!.uid;
      await fakeFirestore.collection('sites').add({
        'userId': userId,
        'name': 'Test Site',
        'url': 'https://example.com',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // Act
      await provider.loadSites();

      // Assert
      expect(provider.sites.length, 1);
      expect(provider.sites.first.name, 'Test Site');
    });

    test('handles empty site collection', () async {
      // Act
      await provider.loadSites();

      // Assert
      expect(provider.sites, isEmpty);
    });

    // Add more tests...
  });

  group('SiteProvider - addSite', () {
    test('creates new site successfully', () async {
      // Arrange
      final site = Site(
        id: '',
        userId: fakeAuth.currentUser!.uid,
        name: 'New Site',
        url: 'https://newsite.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final result = await provider.addSite(site);

      // Assert
      expect(result, isTrue);
      expect(provider.sites.length, 1);
    });

    test('enforces free tier site limit (5 sites)', () async {
      // Arrange - Create 5 sites
      for (int i = 0; i < 5; i++) {
        await provider.addSite(Site(
          id: '',
          userId: fakeAuth.currentUser!.uid,
          name: 'Site $i',
          url: 'https://site$i.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // Act - Try to add 6th site
      final result = await provider.addSite(Site(
        id: '',
        userId: fakeAuth.currentUser!.uid,
        name: 'Site 6',
        url: 'https://site6.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Assert
      expect(result, isFalse);
      expect(provider.sites.length, 5);
    });

    // Add more tests...
  });

  group('SiteProvider - updateSite', () {
    test('resets lastScannedPageIndex when excludedPaths change', () async {
      // Arrange
      final site = Site(
        id: 'test-id',
        userId: fakeAuth.currentUser!.uid,
        name: 'Test Site',
        url: 'https://example.com',
        lastScannedPageIndex: 43,
        excludedPaths: ['old-path/'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeFirestore.collection('sites').doc('test-id').set(site.toFirestore());
      await provider.loadSites();

      // Act
      final updatedSite = site.copyWith(excludedPaths: ['new-path/']);
      await provider.updateSite(updatedSite);

      // Assert
      final result = provider.sites.firstWhere((s) => s.id == 'test-id');
      expect(result.lastScannedPageIndex, 0);  // Reset!
      expect(result.excludedPaths, ['new-path/']);
    });

    // Add more tests...
  });

  group('SiteProvider - deleteSite', () {
    test('deletes site successfully', () async {
      // Setup, Act, Assert...
    });
  });
}
```

### References
- [SiteProvider source](../lib/providers/site_provider.dart)
- [CODEBASE_ANALYSIS_REPORT.md](./CODEBASE_ANALYSIS_REPORT.md)
- [REFACTORING_PLAN.md](./REFACTORING_PLAN.md)

---

## Issue #265: Add comprehensive tests for MonitoringProvider

**Labels:** `testing`, `P0-critical`, `phase-1`  
**Milestone:** v1.0.9  
**Effort:** 5-7 hours

### Description

Add comprehensive test coverage for `MonitoringProvider` to ensure monitoring logic works correctly and safely.

### Current State
- **Test Coverage:** 0%
- **Lines:** ~300
- **Complexity:** High (async, realtime listeners, cooldowns)
- **Risk:** 🔴 CRITICAL - Monitoring may fail silently

### Goals
- Achieve 90%+ test coverage
- Test async operations properly
- Verify cooldown enforcement
- Test result caching logic

### Test Scenarios

#### 1. checkSite()
- ✅ Performs quick scan successfully
- ✅ Caches sitemap status
- ✅ Enforces cooldown period
- ✅ Handles network errors
- ✅ Updates result cache

#### 2. listenToSiteResults()
- ✅ Sets up Firestore listener
- ✅ Receives real-time updates
- ✅ Handles listener errors
- ✅ Cleans up on dispose

#### 3. Cooldown Logic
- ✅ Starts cooldown after check
- ✅ getTimeUntilNextCheck() returns correct duration
- ✅ canCheckSite() respects cooldown
- ✅ Cooldown expires correctly

#### 4. Result Caching
- ✅ getCachedSitemapStatus() returns cached value
- ✅ Cache invalidates correctly
- ✅ getLatestResult() returns most recent

### Acceptance Criteria
- [ ] New file: `test/providers/monitoring_provider_test.dart`
- [ ] 25+ tests added
- [ ] All async operations tested
- [ ] Cooldown logic verified
- [ ] Code review approved

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:sitecat/providers/monitoring_provider.dart';
import 'package:sitecat/models/site.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MonitoringProvider provider;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    provider = MonitoringProvider(firestore: fakeFirestore);
  });

  group('MonitoringProvider - checkSite', () {
    test('performs quick scan successfully', () async {
      final site = Site(/* ... */);
      
      await provider.checkSite(site);
      
      expect(provider.isChecking(site.id), isFalse);
      expect(provider.getCachedSitemapStatus(site.id), isNotNull);
    });

    test('enforces cooldown period', () async {
      final site = Site(/* ... */);
      
      // First check
      await provider.checkSite(site);
      
      // Immediate second check should be blocked
      final canCheck = provider.canCheckSite(site.id);
      expect(canCheck, isFalse);
      
      // Time until next check should be ~30 seconds
      final timeLeft = provider.getTimeUntilNextCheck(site.id);
      expect(timeLeft, isNotNull);
      expect(timeLeft!.inSeconds, greaterThan(0));
    });
  });

  group('MonitoringProvider - listenToSiteResults', () {
    test('receives real-time updates from Firestore', () async {
      final site = Site(id: 'test-id', /* ... */);
      
      // Start listening
      provider.listenToSiteResults(site.id);
      
      // Add a result to Firestore
      await fakeFirestore
          .collection('monitoring_results')
          .add({/* monitoring result data */});
      
      // Wait for listener to fire
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify result received
      final results = provider.getSiteResults(site.id);
      expect(results, isNotEmpty);
    });
  });

  // More test groups...
}
```

### References
- [MonitoringProvider source](../lib/providers/monitoring_provider.dart)
- [CODEBASE_ANALYSIS_REPORT.md](./CODEBASE_ANALYSIS_REPORT.md)

---

## Issue #266: Add comprehensive tests for SubscriptionProvider

**Labels:** `testing`, `P0-critical`, `phase-1`, `iap`  
**Milestone:** v1.0.9  
**Effort:** 6-8 hours

### Description

Add comprehensive test coverage for `SubscriptionProvider` to ensure IAP logic is correct and prevent revenue loss.

### Current State
- **Test Coverage:** 0%
- **Lines:** ~250
- **Complexity:** High (IAP, Firestore, premium flags)
- **Risk:** 🔴 CRITICAL - Financial logic, revenue impact

### Goals
- Achieve 90%+ test coverage
- Mock IAP properly
- Test purchase flow
- Verify entitlement validation
- Test Firestore persistence

### Test Scenarios

#### 1. restorePurchases()
- ✅ Restores valid purchase
- ✅ Handles no purchases
- ✅ Validates entitlement correctly
- ✅ Updates premium status
- ✅ Persists to Firestore

#### 2. purchaseLifetimeAccess()
- ✅ Initiates purchase flow
- ✅ Handles successful purchase
- ✅ Handles purchase cancellation
- ✅ Handles purchase error
- ✅ Updates premium flags

#### 3. Premium Flags
- ✅ hasLifetimeAccess updates correctly
- ✅ Notifies listeners
- ✅ Persists across sessions

#### 4. Firestore Integration
- ✅ Saves purchase to Firestore
- ✅ Loads purchase on init
- ✅ Handles Firestore errors

### Acceptance Criteria
- [ ] New file: `test/providers/subscription_provider_test.dart`
- [ ] 20+ tests added
- [ ] Mock IAP interactions
- [ ] Financial logic validated
- [ ] Code review approved

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sitecat/providers/subscription_provider.dart';

class MockInAppPurchase extends Mock implements InAppPurchase {}

void main() {
  late MockInAppPurchase mockIAP;
  late SubscriptionProvider provider;

  setUp(() {
    mockIAP = MockInAppPurchase();
    provider = SubscriptionProvider(inAppPurchase: mockIAP);
  });

  group('SubscriptionProvider - restorePurchases', () {
    test('restores valid lifetime purchase', () async {
      // Arrange
      final purchase = PurchaseDetails(/* mock purchase data */);
      when(mockIAP.restorePurchases()).thenAnswer((_) async => [purchase]);
      
      // Act
      await provider.restorePurchases();
      
      // Assert
      expect(provider.hasLifetimeAccess, isTrue);
    });

    test('handles no purchases to restore', () async {
      when(mockIAP.restorePurchases()).thenAnswer((_) async => []);
      
      await provider.restorePurchases();
      
      expect(provider.hasLifetimeAccess, isFalse);
    });
  });

  group('SubscriptionProvider - purchaseLifetimeAccess', () {
    test('completes purchase successfully', () async {
      // Mock successful purchase flow
      // Verify premium flags updated
      // Verify Firestore saved
    });
  });

  // More test groups...
}
```

### References
- [SubscriptionProvider source](../lib/providers/subscription_provider.dart)
- [CODEBASE_ANALYSIS_REPORT.md](./CODEBASE_ANALYSIS_REPORT.md)

---

## Issue #267: Add comprehensive tests for Models

**Labels:** `testing`, `P1-high`, `phase-1`  
**Milestone:** v1.0.9  
**Effort:** 3-5 hours

### Description

Add test coverage for data models to ensure serialization and validation work correctly.

### Current State
- **Test Coverage:** ~10%
- **Files:** `Site`, `BrokenLink`, `LinkCheckResult`, `MonitoringResult`
- **Risk:** ⚠️ HIGH - Data inconsistency, invalid state

### Goals
- Test serialization round-trips (toFirestore/fromFirestore)
- Test validation logic
- Cover edge cases (null fields, invalid data)
- Achieve 80%+ coverage

### Test Scenarios

#### 1. Site Model
- ✅ fromFirestore() parses correctly
- ✅ toFirestore() serializes correctly
- ✅ Round-trip preserves data
- ✅ Handles null optional fields
- ✅ copyWith() works correctly
- ✅ Validation (URL format, etc.)

#### 2. BrokenLink Model
- ✅ fromMap() parses correctly
- ✅ toMap() serializes correctly
- ✅ Validation logic

#### 3. LinkCheckResult Model
- ✅ Serialization
- ✅ Result merging logic (for Continue scans)
- ✅ Edge cases

### Acceptance Criteria
- [ ] New files: `test/models/*_test.dart`
- [ ] 15+ tests added
- [ ] Serialization verified
- [ ] Edge cases covered
- [ ] Code review approved

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sitecat/models/site.dart';

void main() {
  group('Site Model', () {
    test('fromFirestore() parses data correctly', () {
      final data = {
        'userId': 'user123',
        'name': 'Test Site',
        'url': 'https://example.com',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'excludedPaths': ['path1/', 'path2/'],
      };
      
      final doc = FakeDocumentSnapshot('doc1', data);
      final site = Site.fromFirestore(doc);
      
      expect(site.userId, 'user123');
      expect(site.name, 'Test Site');
      expect(site.excludedPaths.length, 2);
    });

    test('toFirestore() serializes correctly', () {
      final site = Site(
        id: 'test-id',
        userId: 'user123',
        name: 'Test Site',
        url: 'https://example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final data = site.toFirestore();
      
      expect(data['userId'], 'user123');
      expect(data['name'], 'Test Site');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('round-trip preserves data', () {
      final original = Site(/* ... */);
      final data = original.toFirestore();
      final doc = FakeDocumentSnapshot('doc1', data);
      final restored = Site.fromFirestore(doc);
      
      expect(restored.name, original.name);
      expect(restored.url, original.url);
      // ...verify all fields
    });
  });
}
```

### References
- [Model source files](../lib/models/)
- [CODEBASE_ANALYSIS_REPORT.md](./CODEBASE_ANALYSIS_REPORT.md)

---

## Summary

### Phase 1 Overview
- **Total Issues:** 4 (#264, #265, #266, #267)
- **Total Effort:** 18-26 hours
- **Expected Coverage Increase:** 32% → 50%+
- **Priority:** All P0-P1 (Critical/High)

### Issue Creation Checklist
- [ ] Create Issue #264 (SiteProvider)
- [ ] Create Issue #265 (MonitoringProvider)
- [ ] Create Issue #266 (SubscriptionProvider)
- [ ] Create Issue #267 (Models)
- [ ] Add to v1.0.9 Milestone
- [ ] Assign appropriate labels
- [ ] Link to analysis docs

### Next Steps
1. Review and approve templates
2. Create issues on GitHub
3. Start with #264 (SiteProvider) - highest priority
4. Work sequentially or parallelize if multiple developers

---

**Templates Maintained By:** AI Assistant  
**Last Updated:** 2025-12-11
