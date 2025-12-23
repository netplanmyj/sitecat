import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';
import 'dart:io' show Platform;
import '../constants/error_messages.dart';

/// Firebase Authentication サービス
/// Google Sign-In を使用したユーザー認証を管理する
class AuthService {
  static const String _firebaseAppName = 'sitecat-current';

  late final FirebaseAuth _auth;
  late final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  AuthService({FirebaseAuth? auth}) {
    final app = Firebase.app(_firebaseAppName);
    _auth = auth ?? FirebaseAuth.instanceFor(app: app);

    // 開発/本番で適切な iOS Client ID を選択
    // FirebaseApp の projectId を用いて環境を判定
    final projectId = app.options.projectId;
    final isProd = projectId == 'sitecat-prod';
    final iosClientId = isProd
        // 本番（sitecat-prod）の iOS クライアントID
        ? '775763766826-st83dsn9npb5i4r74g4i930ceii7flq5.apps.googleusercontent.com'
        // 開発（sitecat-dev）の iOS クライアントID（Info.plist の URL scheme と一致）
        : '974974534435-acs3q36ciqdm67u3ba5ea2ruk2ov9mo3.apps.googleusercontent.com';

    _googleSignIn = GoogleSignIn(clientId: iosClientId);
    _logger.i(
      'GoogleSignIn configured for ${isProd ? 'PROD' : 'DEV'} with clientId: $iosClientId',
    );
  }

  /// 現在のユーザー取得
  User? get currentUser => _auth.currentUser;

  /// 認証状態の変更をListenするStream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google Sign-In認証フロー
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign-In フロー開始
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // ユーザーがサインインをキャンセルした場合
      if (googleUser == null) {
        return null;
      }

      // Google認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase認証用の認証情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase認証を実行
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // 初回ログイン時のユーザードキュメント作成
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      _logger.d(
        'Google sign-in completed for ${userCredential.user!.uid}. '
        'isNewUser: $isNewUser',
      );

      if (isNewUser) {
        _logger.d(
          'Calling _createUserDocument for new user ${userCredential.user!.uid}',
        );
        await _createUserDocument(userCredential.user!);
      } else {
        _logger.d(
          'Calling _updateLastLogin for existing user ${userCredential.user!.uid}',
        );
        // 既存ユーザーのlastLoginAtを更新（siteCount移行も含む）
        await _updateLastLogin(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Firebase認証エラー
      throw _handleAuthException(e);
    } catch (e) {
      // その他のエラー
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Apple Sign-In認証フロー
  Future<UserCredential?> signInWithApple() async {
    try {
      // Sign in with Apple が利用可能かチェック（iOS 13.0+ / macOS 10.15+）
      if (!Platform.isIOS && !Platform.isMacOS) {
        throw Exception(
          'Sign in with Apple is only available on iOS and macOS',
        );
      }

      // Sign in with Apple のリクエスト
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // OAuthProviderを使用してFirebase認証情報を作成
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase認証を実行
      final UserCredential userCredential = await _auth.signInWithCredential(
        oauthCredential,
      );

      // 初回ログイン時のユーザードキュメント作成
      // Apple Sign-Inの場合、displayNameとemailが取得できない場合がある
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(
          userCredential.user!,
          displayName:
              appleCredential.givenName != null &&
                  appleCredential.familyName != null
              ? '${appleCredential.givenName} ${appleCredential.familyName}'
              : null,
        );
      } else {
        // 既存ユーザーのlastLoginAtを更新
        await _updateLastLogin(userCredential.user!);
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Apple Sign-In固有のエラー
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          return null; // ユーザーがキャンセルした場合
        case AuthorizationErrorCode.failed:
          throw Exception('Apple sign-in failed');
        case AuthorizationErrorCode.invalidResponse:
          throw Exception('Invalid response from Apple');
        case AuthorizationErrorCode.notHandled:
          throw Exception('Apple sign-in was not handled');
        case AuthorizationErrorCode.unknown:
          throw Exception('Unknown error occurred during Apple sign-in');
        default:
          throw Exception('Apple sign-in error: ${e.code}');
      }
    } on FirebaseAuthException catch (e) {
      // Firebase認証エラー
      throw _handleAuthException(e);
    } catch (e) {
      // その他のエラー
      throw Exception('Apple sign-in failed: $e');
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Delete account
  /// Deletes all user data (profile, sites, monitoring history) and
  /// removes the account from Firebase Authentication.
  ///
  /// Note: The Firebase Authentication account deletion is performed last.
  /// This allows the user to log in again and retry the deletion if an
  /// error occurs during the process.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    String? errorMessage;

    try {
      final userId = user.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      // Phase 1: Delete all user data from Firestore
      // If this phase fails, the user can log in again and retry

      // 1. Delete all subcollections under the user document

      // Delete site information
      final sitesSnapshot = await userDocRef.collection('sites').get();
      await _batchDelete(sitesSnapshot.docs);

      // Delete linkCheckResults and its brokenLinks subcollection
      final linkCheckSnapshot = await userDocRef
          .collection('linkCheckResults')
          .get();
      for (final doc in linkCheckSnapshot.docs) {
        // Delete brokenLinks subcollection first
        final brokenLinksSnapshot = await doc.reference
            .collection('brokenLinks')
            .get();
        await _batchDelete(brokenLinksSnapshot.docs);
      }
      // Delete linkCheckResults documents themselves
      await _batchDelete(linkCheckSnapshot.docs);

      // Delete monitoringResults subcollection
      final monitoringSnapshot = await userDocRef
          .collection('monitoringResults')
          .get();
      await _batchDelete(monitoringSnapshot.docs);

      // Note: subscription, alerts, statistics are not deleted by the client
      // as per Firestore rules (Functions manages subscription)
      // alerts and statistics are optional and will be cleaned up separately

      // Phase 2: Call Cloud Function to cleanup all user data
      // This must happen while the user is still authenticated
      // The function will delete subscription, sites, monitoring results, linkCheckResults, and user document
      final callable = FirebaseFunctions.instance.httpsCallable(
        'onAuthUserDeleted',
      );
      try {
        await callable.call();
        _logger.d(
          'Cloud Function onAuthUserDeleted completed successfully for user ${user.uid}',
        );
      } catch (cfError) {
        _logger.e('Cloud Function failed: $cfError');
        errorMessage =
            'Failed to cleanup user data. Please try again. Error: $cfError';
        // Rethrow to prevent further execution if cleanup fails
        rethrow;
      }

      // Phase 3: Re-authenticate user (required for delete operation)
      // Check the user's sign-in provider and handle accordingly
      try {
        // Determine which provider was used for sign-in
        final providers = user.providerData.map((p) => p.providerId).toList();

        if (providers.contains('google.com')) {
          // Google Sign-In requires fresh token for sensitive operations
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser != null) {
            final GoogleSignInAuthentication googleAuth =
                await googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
          }
        } else if (providers.contains('apple.com')) {
          // Apple Sign-In requires re-authentication as well
          final appleCredential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );
          final oauthCredential = OAuthProvider('apple.com').credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );
          await user.reauthenticateWithCredential(oauthCredential);
        }
      } catch (reauthError) {
        // If re-auth fails, continue anyway (might work without it)
      }

      // Phase 4: Delete user from Firebase Authentication
      // Important: Executed after successful Firestore data deletion
      // This allows the user to retry on error
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          errorMessage =
              'For security reasons, account deletion requires recent login. Please sign out and sign in again.';
        } else {
          errorMessage = 'Account deletion failed: ${e.message}';
        }
        // Continue to signOut even if user.delete() fails
      }
    } catch (e) {
      // If error occurs during Firestore data deletion
      // Firebase Auth account remains, so user can retry
      errorMessage = 'Account deletion failed: $e';
    } finally {
      // Phase 5: Cleanup - Always sign out regardless of errors
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (e) {
        // Ignore signOut errors
      }
    }

    // Throw error if any occurred, but after signOut is completed
    if (errorMessage != null) {
      throw Exception(errorMessage);
    }
  }

  /// 初回ログイン時のユーザードキュメント作成
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    _logger.d('_createUserDocument called for user ${user.uid}');
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // 既に存在するドキュメントをチェック（StoreKit復元の場合、不完全ドキュメントが存在する可能性）
      final existingDoc = await userDoc.get();

      if (existingDoc.exists) {
        final existingData = existingDoc.data();

        // 既存ドキュメントが不完全かチェック
        if (existingData != null) {
          final userProfileFields = [
            'siteCount',
            'email',
            'createdAt',
            'uid',
            'lastLoginAt',
            'settings',
          ];
          final hasMissingProfileFields = userProfileFields.any(
            (field) => !existingData.containsKey(field),
          );

          if (hasMissingProfileFields) {
            // 不完全なドキュメントを修復（Cloud Functionで作成された不完全なドキュメント）
            final existingPlan = existingData['plan'] as String?;
            final resolvedPlan = existingPlan ?? 'free';

            _logger.i(
              'Repairing incomplete user document during _createUserDocument for ${user.uid}. '
              'Existing plan: $existingPlan, will be preserved as: $resolvedPlan',
            );

            await userDoc.set({
              'uid': user.uid,
              'email': user.email,
              'displayName': displayName ?? user.displayName,
              'photoURL': user.photoURL,
              'plan': resolvedPlan, // Cloud Functionが設定した planを保持
              'siteCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'settings': {'notifications': true, 'emailAlerts': true},
              // subscription は保持される（merge: true のため）
            }, SetOptions(merge: true));

            _logger.i(
              'Successfully repaired incomplete user document in _createUserDocument for ${user.uid}',
            );
            return;
          }

          // 既存ドキュメントが完全な場合はスキップ
          _logger.d(
            'User document already exists and is complete for ${user.uid}, skipping creation',
          );
          return;
        }
      }

      // ドキュメントが存在しない場合は新規作成
      _logger.d('Creating new user document for ${user.uid}');
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName,
        'photoURL': user.photoURL,
        'plan': 'free', // デフォルトは無料プラン
        'siteCount': 0, // サイト数カウンター（Functionsが更新）
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'settings': {'notifications': true, 'emailAlerts': true},
      });
      _logger.i('Successfully created new user document for ${user.uid}');
    } catch (e) {
      throw Exception('Failed to create user document: $e');
    }
  }

  /// 最終ログイン時刻の更新
  Future<void> _updateLastLogin(User user) async {
    _logger.d('_updateLastLogin called for user ${user.uid}');
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // ドキュメントを取得
      final docSnapshot = await userDoc.get();

      final data = docSnapshot.data();

      // ドキュメント存在状況を判定
      final documentExists = docSnapshot.exists;

      // 不完全なドキュメントを検出
      // 購入リストアで作成された不完全なドキュメント（plan/subscription のみ）を検出
      //
      // 不完全ドキュメント = ユーザープロフィール必須フィールドが1つ以上欠落している
      // （plan/subscriptionは存在しても、ユーザーの基本情報が揃っていない）
      //
      // ユーザープロフィール必須フィールド（_createUserDocument で必ず作成される）:
      // - siteCount, email, createdAt, uid, lastLoginAt, settings
      // - displayName, photoURL (null可能だが、Firestore に記録される)
      bool isIncompleteDocument = false;

      // ケース1: ドキュメントが存在しない場合
      if (!documentExists) {
        _logger.w(
          'User document does not exist for ${user.uid}. '
          'This can happen after account deletion. '
          'Creating new document via _createUserDocument().',
        );
        // ドキュメントが存在しない場合は新規作成
        await _createUserDocument(user);
        _logger.d(
          'Successfully created user document via _updateLastLogin for ${user.uid}',
        );
        return;
      }

      // ケース2: ドキュメントは存在するが、プロフィール情報が不完全な場合
      if (data != null) {
        final userProfileFields = [
          'siteCount',
          'email',
          'createdAt',
          'uid',
          'lastLoginAt',
          'settings',
        ];
        // 存在しないフィールドが1つでもあるか？ = 不完全
        // any() で1つ以上の欠落フィールドを検出
        final hasMissingProfileFields = userProfileFields.any(
          (field) => !data.containsKey(field),
        );
        if (hasMissingProfileFields) {
          // Cloud Functionのみが作成したドキュメント（購入リストアで発生）
          // plan/subscription は存在する可能性があるが、ユーザープロフィール情報が揃っていない
          isIncompleteDocument = true;
          _logger.w(
            'Detected incomplete user document (likely created by purchase restore). '
            'User profile fields missing: ${userProfileFields.where((f) => !data.containsKey(f)).toList()}. '
            'Will preserve plan and subscription, then add missing fields.',
          );
        }
      }

      if (isIncompleteDocument) {
        // 不完全なドキュメントの場合は、既存の plan と subscription を保持しつつ
        // 必須フィールドを追加
        //
        // set() with merge: true を使用する理由:
        // - update() は存在しないフィールドでエラーになる可能性がある
        // - merge: true により既存フィールド（plan, subscription）を保持
        // - 新しいフィールドのみを追加して完全なドキュメントにする

        // 既存のplanフィールドを確認（Cloud Functionが設定済みの場合を考慮）
        final existingPlan = data?['plan'] as String?;
        final resolvedPlan = existingPlan ?? 'free';

        _logger.i(
          'Repairing incomplete user document for ${user.uid}. '
          'Existing plan: $existingPlan, resolved plan: $resolvedPlan',
        );

        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'plan': resolvedPlan, // 既存のplanを保持、なければfree
          'siteCount': 0, // サイト数カウンター（Functionsが更新）
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'settings': {'notifications': true, 'emailAlerts': true},
          // plan と subscription は保持される（merge: true のため）
        }, SetOptions(merge: true));

        _logger.i(
          'Successfully repaired incomplete user document for ${user.uid}',
        );
        return;
      }

      // 必須フィールドの存在確認と初期化
      //
      // update() を使用する理由:
      // - ドキュメントの存在が既に確認済み（line 321でチェック済み）
      // - 不足フィールドのみを追加する安全な操作
      // - 既存フィールドを上書きしない
      final missingFields = <String, dynamic>{};

      // siteCount が存在しない場合
      if (data == null || !data.containsKey('siteCount')) {
        missingFields['siteCount'] = 0;
      }

      // email が存在しない場合
      if (data == null || !data.containsKey('email')) {
        missingFields['email'] = user.email;
      }

      // createdAt が存在しない場合
      if (data == null || !data.containsKey('createdAt')) {
        missingFields['createdAt'] = FieldValue.serverTimestamp();
      }

      // uid が存在しない場合
      if (data == null || !data.containsKey('uid')) {
        missingFields['uid'] = user.uid;
      }

      // plan が存在しない場合
      if (data == null || !data.containsKey('plan')) {
        missingFields['plan'] = 'free';
      }

      // 常に lastLoginAt を更新
      missingFields['lastLoginAt'] = FieldValue.serverTimestamp();

      // 不足フィールドがある場合は一括更新
      if (missingFields.isNotEmpty) {
        await userDoc.update(missingFields);
      }
    } catch (e) {
      // ログ更新の失敗は認証を阻害しない
      _logger.w('Failed to update last login: $e');
    }
  }

  /// FirebaseAuthException の処理
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return ErrorMessages.accountExistsWithDifferentCredential;
      case 'invalid-credential':
        return ErrorMessages.invalidCredential;
      case 'operation-not-allowed':
        return ErrorMessages.operationNotAllowed;
      case 'user-disabled':
        return ErrorMessages.userDisabled;
      case 'user-not-found':
        return ErrorMessages.userNotFound;
      case 'wrong-password':
        return ErrorMessages.wrongPassword;
      case 'invalid-verification-code':
        return ErrorMessages.invalidVerificationCode;
      case 'invalid-verification-id':
        return ErrorMessages.invalidVerificationId;
      case 'network-request-failed':
        return ErrorMessages.networkRequestFailed;
      case 'too-many-requests':
        return ErrorMessages.tooManyRequests;
      default:
        return '${ErrorMessages.authenticationError} ${e.message}';
    }
  }

  /// Batch delete helper
  /// Due to Firestore limitations, maximum 500 operations per batch
  Future<void> _batchDelete(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    for (final doc in docs) {
      batch.delete(doc.reference);
      operationCount++;

      // Firestore batch limit is 500 operations
      if (operationCount == 500) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }
  }
}
