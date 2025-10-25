import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Authentication サービス
/// Google Sign-In を使用したユーザー認証を管理する
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
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

  /// サインアウト
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// アカウント削除
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      // Firestoreからユーザードキュメントを削除
      await _firestore.collection('users').doc(user.uid).delete();

      // Firebase Authenticationからユーザーを削除
      await user.delete();

      // Google Sign-Inからもサインアウト
      await _googleSignIn.signOut();
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  /// 初回ログイン時のユーザードキュメント作成
  Future<void> _createUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);

      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
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
}
