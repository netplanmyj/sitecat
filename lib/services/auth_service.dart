import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

/// Firebase Authentication サービス
/// Google Sign-In を使用したユーザー認証を管理する
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOSのクライアントIDを明示的に指定
    clientId:
        '974974534435-acs3q36ciqdm67u3ba5ea2ruk2ov9mo3.apps.googleusercontent.com',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      } else {
        // 既存ユーザーのlastLoginAtを更新
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

      // 2. Delete user document
      await userDocRef.delete();

      // Phase 2: Delete user from Firebase Authentication
      // Important: Executed after successful Firestore data deletion
      // This allows the user to retry on error
      await user.delete();

      // Phase 3: Cleanup
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      // Handle error when re-authentication is required
      if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security reasons, account deletion requires recent login. Please sign out and sign in again.',
        );
      }
      throw Exception('Account deletion failed: ${e.message}');
    } catch (e) {
      // If error occurs during Firestore data deletion
      // Firebase Auth account remains, so user can retry
      throw Exception('Account deletion failed: $e');
    }
  }

  /// 初回ログイン時のユーザードキュメント作成
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName,
        'photoURL': user.photoURL,
        'plan': 'free', // デフォルトは無料プラン
        'siteCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'settings': {'notifications': true, 'emailAlerts': true},
      });
    } catch (e) {
      throw Exception('Failed to create user document: $e');
    }
  }

  /// 最終ログイン時刻の更新
  Future<void> _updateLastLogin(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.update({'lastLoginAt': FieldValue.serverTimestamp()});
    } catch (e) {
      // ログ更新の失敗は認証を阻害しない
      // デバッグログ: Failed to update last login: $e
    }
  }

  /// FirebaseAuthException の処理
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは既に別の認証方法で登録されています。';
      case 'invalid-credential':
        return '認証情報が無効です。';
      case 'operation-not-allowed':
        return 'この認証方法は有効化されていません。';
      case 'user-disabled':
        return 'このアカウントは無効化されています。';
      case 'user-not-found':
        return 'ユーザーが見つかりません。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'invalid-verification-code':
        return '認証コードが無効です。';
      case 'invalid-verification-id':
        return '認証IDが無効です。';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく待ってから再試行してください。';
      default:
        return '認証エラーが発生しました: ${e.message}';
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
