import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// 認証状態管理Provider
/// ChangeNotifierを継承し、認証状態の変更をUIに通知する
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  /// 初期化
  AuthProvider() {
    _init();
  }

  /// 初期化処理
  void _init() {
    // 認証状態の変更を監視
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      _clearError();
      notifyListeners();
    });
  }

  /// Google Sign-In実行
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signInWithGoogle();

      if (userCredential != null) {
        // 認証成功
        _user = userCredential.user;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Apple Sign-In実行
  Future<void> signInWithApple() async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signInWithApple();

      if (userCredential != null) {
        // 認証成功
        _user = userCredential.user;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// サインアウト実行
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// アカウント削除実行
  Future<void> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.deleteAccount();
      _user = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// ローディング状態の設定
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// エラーメッセージの設定
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// エラーメッセージのクリア
  void _clearError() {
    _errorMessage = null;
  }

  /// エラー表示完了後のクリア
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
