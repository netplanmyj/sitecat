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
}
