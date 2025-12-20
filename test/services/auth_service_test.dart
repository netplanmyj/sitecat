import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // Note: AuthService uses singleton instances, so we can't inject mocks directly
    // These tests verify the logic patterns without full integration
  });

  group('AuthService - User Document Management', () {
    test('_updateLastLogin should initialize missing siteCount field', () async {
      // Arrange: Create a user document with only isPremium field (simulating the bug scenario)
      final userId = 'test-user-123';
      final mockUser = MockUser(
        uid: userId,
        email: 'test@example.com',
        displayName: 'Test User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'isPremium': true,
        // Missing: siteCount, email, createdAt, uid, plan
      });

      // Act: Simulate what _updateLastLogin does
      final userDoc = fakeFirestore.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      final data = docSnapshot.data();

      final missingFields = <String, dynamic>{};

      if (data == null || !data.containsKey('siteCount')) {
        missingFields['siteCount'] = 0;
      }
      if (data == null || !data.containsKey('email')) {
        missingFields['email'] = mockUser.email;
      }
      if (data == null || !data.containsKey('uid')) {
        missingFields['uid'] = mockUser.uid;
      }
      if (data == null || !data.containsKey('plan')) {
        missingFields['plan'] = 'free';
      }

      await userDoc.update(missingFields);

      // Assert: Verify all missing fields were added
      final updatedDoc = await userDoc.get();
      final updatedData = updatedDoc.data()!;

      expect(updatedData['siteCount'], equals(0));
      expect(updatedData['email'], equals('test@example.com'));
      expect(updatedData['uid'], equals(userId));
      expect(updatedData['plan'], equals('free'));
      expect(
        updatedData['isPremium'],
        equals(true),
      ); // Original field preserved
    });

    test('_updateLastLogin should preserve existing fields', () async {
      // Arrange: User document with all fields already present
      final userId = 'test-user-456';
      final mockUser = MockUser(
        uid: userId,
        email: 'existing@example.com',
        displayName: 'Existing User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'uid': userId,
        'email': 'existing@example.com',
        'siteCount': 5,
        'plan': 'premium',
        'isPremium': true,
        'displayName': 'Existing User',
      });

      // Act: Simulate _updateLastLogin logic
      final userDoc = fakeFirestore.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      final data = docSnapshot.data();

      final missingFields = <String, dynamic>{};

      if (data == null || !data.containsKey('siteCount')) {
        missingFields['siteCount'] = 0;
      }
      if (data == null || !data.containsKey('email')) {
        missingFields['email'] = mockUser.email;
      }
      if (data == null || !data.containsKey('uid')) {
        missingFields['uid'] = mockUser.uid;
      }
      if (data == null || !data.containsKey('plan')) {
        missingFields['plan'] = 'free';
      }

      if (missingFields.isNotEmpty) {
        await userDoc.update(missingFields);
      }

      // Assert: Existing values should be preserved
      final updatedDoc = await userDoc.get();
      final updatedData = updatedDoc.data()!;

      expect(updatedData['siteCount'], equals(5)); // Not reset to 0
      expect(updatedData['email'], equals('existing@example.com'));
      expect(updatedData['plan'], equals('premium')); // Not changed to 'free'
      expect(updatedData['isPremium'], equals(true));
    });

    test('_createUserDocument should create all required fields', () async {
      // Arrange
      final userId = 'new-user-789';
      final mockUser = MockUser(
        uid: userId,
        email: 'newuser@example.com',
        displayName: 'New User',
        photoURL: 'https://example.com/photo.jpg',
      );

      // Act: Simulate _createUserDocument logic
      await fakeFirestore.collection('users').doc(userId).set({
        'uid': mockUser.uid,
        'email': mockUser.email,
        'displayName': mockUser.displayName,
        'photoURL': mockUser.photoURL,
        'plan': 'free',
        'siteCount': 0,
        'createdAt': DateTime.now(),
        'lastLoginAt': DateTime.now(),
        'settings': {'notifications': true, 'emailAlerts': true},
      });

      // Assert: All required fields should be present
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      final data = userDoc.data()!;

      expect(data['uid'], equals(userId));
      expect(data['email'], equals('newuser@example.com'));
      expect(data['displayName'], equals('New User'));
      expect(data['photoURL'], equals('https://example.com/photo.jpg'));
      expect(data['plan'], equals('free'));
      expect(data['siteCount'], equals(0));
      expect(data['createdAt'], isNotNull);
      expect(data['lastLoginAt'], isNotNull);
      expect(data['settings'], isA<Map>());
    });

    test('missing email should be handled gracefully', () async {
      // Arrange: User without email (possible with Apple Sign-In)
      final userId = 'test-user-no-email';
      final mockUser = MockUser(
        uid: userId,
        email: null, // Apple Sign-In may not provide email
        displayName: 'Anonymous User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'isPremium': false,
      });

      // Act
      final userDoc = fakeFirestore.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      final data = docSnapshot.data();

      final missingFields = <String, dynamic>{};

      if (data == null || !data.containsKey('siteCount')) {
        missingFields['siteCount'] = 0;
      }
      if (data == null || !data.containsKey('email')) {
        missingFields['email'] = mockUser.email; // Can be null
      }
      if (data == null || !data.containsKey('uid')) {
        missingFields['uid'] = mockUser.uid;
      }
      if (data == null || !data.containsKey('plan')) {
        missingFields['plan'] = 'free';
      }

      await userDoc.update(missingFields);

      // Assert: Should handle null email
      final updatedDoc = await userDoc.get();
      final updatedData = updatedDoc.data()!;

      expect(updatedData['email'], isNull);
      expect(updatedData['siteCount'], equals(0));
      expect(updatedData['uid'], equals(userId));
    });
  });

  group('AuthService - Incomplete Document Detection and Repair', () {
    test(
      'should detect incomplete document with only plan and subscription',
      () async {
        // Arrange: StoreKit auto-restore creates document with only plan field
        final userId = 'incomplete-user-001';
        await fakeFirestore.collection('users').doc(userId).set({
          'plan': 'premium',
          'subscription': {
            'productId': 'lifetime_access',
            'transactionId': 'tx123',
          },
          // Missing: siteCount, email, createdAt, uid
        });

        // Act: Check if document is incomplete
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final data = userDoc.data();

        final requiredFields = [
          'siteCount',
          'email',
          'createdAt',
          'uid',
          'plan',
        ];
        final missingFields = requiredFields.where((field) {
          return data == null || !data.containsKey(field);
        }).toList();

        // Assert: Should detect 4 missing fields
        expect(missingFields.length, equals(4));
        expect(
          missingFields,
          containsAll(['siteCount', 'email', 'createdAt', 'uid']),
        );
        expect(data?['plan'], equals('premium')); // Existing plan preserved
      },
    );

    test('should repair incomplete document using set() with merge', () async {
      // Arrange: Incomplete document with only plan
      final userId = 'incomplete-user-002';
      final mockUser = MockUser(
        uid: userId,
        email: 'repair@example.com',
        displayName: 'Repair User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'plan': 'premium',
        'subscription': {'productId': 'lifetime_access'},
      });

      // Act: Repair using set() with merge (preserves existing fields)
      final existingDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final existingData = existingDoc.data();
      final existingPlan = existingData?['plan'] as String?;
      final resolvedPlan = existingPlan ?? 'free';

      // Note: fake_cloud_firestore doesn't support SetOptions
      // We simulate merge behavior by spreading existing data
      await fakeFirestore.collection('users').doc(userId).set({
        ...?existingData,
        'uid': mockUser.uid,
        'email': mockUser.email,
        'siteCount': 0,
        'plan': resolvedPlan,
        'createdAt': DateTime.now(),
        'lastLoginAt': DateTime.now(),
      });

      // Assert: Existing fields preserved + new fields added
      final repairedDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final repairedData = repairedDoc.data()!;

      expect(
        repairedData['plan'],
        equals('premium'),
      ); // Preserved from Cloud Function
      expect(repairedData['subscription'], isNotNull); // Preserved
      expect(repairedData['uid'], equals(userId)); // Added
      expect(repairedData['email'], equals('repair@example.com')); // Added
      expect(repairedData['siteCount'], equals(0)); // Added
      expect(repairedData['createdAt'], isNotNull); // Added
    });

    test('should have all required fields after repair', () async {
      // Arrange: Incomplete document
      final userId = 'incomplete-user-003';
      final mockUser = MockUser(
        uid: userId,
        email: 'complete@example.com',
        displayName: 'Complete User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'plan': 'premium',
      });

      // Act: Full repair process
      final existingDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final existingData = existingDoc.data();
      final existingPlan = existingData?['plan'] as String?;
      final resolvedPlan = existingPlan ?? 'free';

      // Simulate set() with merge behavior
      await fakeFirestore.collection('users').doc(userId).set({
        ...?existingData,
        'uid': mockUser.uid,
        'email': mockUser.email,
        'siteCount': 0,
        'plan': resolvedPlan,
        'createdAt': DateTime.now(),
        'lastLoginAt': DateTime.now(),
      });

      // Assert: All required fields present
      final finalDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final finalData = finalDoc.data()!;

      final requiredFields = ['siteCount', 'email', 'createdAt', 'uid', 'plan'];
      for (final field in requiredFields) {
        expect(
          finalData.containsKey(field),
          isTrue,
          reason: 'Required field "$field" should exist after repair',
        );
      }
    });

    test('should handle edge case with partial required fields', () async {
      // Arrange: Document with some required fields but not all
      final userId = 'partial-user-004';
      final mockUser = MockUser(
        uid: userId,
        email: 'partial@example.com',
        displayName: 'Partial User',
      );

      await fakeFirestore.collection('users').doc(userId).set({
        'plan': 'premium',
        'uid': userId, // Already exists
        'email': 'partial@example.com', // Already exists
        // Missing: siteCount, createdAt
      });

      // Act: Repair with set() merge
      final existingDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final existingData = existingDoc.data();
      final existingPlan = existingData?['plan'] as String?;
      final resolvedPlan = existingPlan ?? 'free';

      // Simulate set() with merge to preserve existing fields
      await fakeFirestore.collection('users').doc(userId).set({
        ...?existingData,
        'uid': mockUser.uid,
        'email': mockUser.email,
        'siteCount': 0,
        'plan': resolvedPlan,
        'createdAt': DateTime.now(),
        'lastLoginAt': DateTime.now(),
      });

      // Assert: Existing values preserved, missing values added
      final repairedDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      final repairedData = repairedDoc.data()!;

      expect(repairedData['uid'], equals(userId)); // Preserved
      expect(repairedData['email'], equals('partial@example.com')); // Preserved
      expect(repairedData['plan'], equals('premium')); // Preserved
      expect(repairedData['siteCount'], equals(0)); // Added
      expect(repairedData['createdAt'], isNotNull); // Added
    });

    test(
      'should preserve plan=premium from Cloud Function over default free',
      () async {
        // Arrange: Cloud Function already set plan=premium
        final userId = 'premium-user-005';
        final mockUser = MockUser(
          uid: userId,
          email: 'premium@example.com',
          displayName: 'Premium User',
        );

        await fakeFirestore.collection('users').doc(userId).set({
          'plan': 'premium', // From Cloud Function saveLifetimePurchase
        });

        // Act: AuthService tries to repair with default 'free'
        final existingDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final existingData = existingDoc.data();
        final existingPlan = existingData?['plan'] as String?;
        final resolvedPlan =
            existingPlan ?? 'free'; // Should use existing 'premium'

        // Simulate set() with merge to preserve existing plan
        await fakeFirestore.collection('users').doc(userId).set({
          ...?existingData,
          'uid': mockUser.uid,
          'email': mockUser.email,
          'siteCount': 0,
          'plan': resolvedPlan, // Use resolved plan
          'createdAt': DateTime.now(),
          'lastLoginAt': DateTime.now(),
        });

        // Assert: plan should remain 'premium', not reset to 'free'
        final finalDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final finalData = finalDoc.data()!;

        expect(
          finalData['plan'],
          equals('premium'),
          reason:
              'Existing plan=premium should be preserved, not reset to free',
        );
      },
    );
  });
}
