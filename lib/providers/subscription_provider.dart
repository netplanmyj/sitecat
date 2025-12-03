import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';

/// サブスクリプション状態管理Provider
class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService;

  bool _hasLifetimeAccess = false;
  bool _isLoading = false;
  String? _error;
  ProductDetails? _productDetails;

  SubscriptionProvider(this._subscriptionService);

  /// 買い切り版のアクセス権があるか
  bool get hasLifetimeAccess => _hasLifetimeAccess;

  /// ローディング中か
  bool get isLoading => _isLoading;

  /// エラーメッセージ
  String? get error => _error;

  /// 商品情報
  ProductDetails? get productDetails => _productDetails;

  /// 商品価格（フォーマット済み）
  String get price => _productDetails?.price ?? '¥1,220';

  /// 初期化
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _subscriptionService.initialize();
      await _checkLifetimeAccess();
      await _loadProductDetails();
    } catch (e) {
      _error = 'サブスクリプション情報の取得に失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 買い切り版のアクセス権をチェック
  Future<void> _checkLifetimeAccess() async {
    try {
      _hasLifetimeAccess = await _subscriptionService.hasLifetimeAccess();
      notifyListeners();
    } catch (e) {
      _error = 'アクセス権の確認に失敗しました: $e';
      notifyListeners();
    }
  }

  /// 商品情報を読み込み
  Future<void> _loadProductDetails() async {
    try {
      _productDetails = await _subscriptionService.getProductDetails();
      notifyListeners();
    } catch (e) {
      _error = '商品情報の取得に失敗しました: $e';
      notifyListeners();
    }
  }

  /// 買い切り版を購入
  Future<bool> purchaseLifetime() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _subscriptionService.purchaseLifetimeAccess();

      if (success) {
        // 購入後、状態を更新
        await _checkLifetimeAccess();
      } else {
        _error = '購入に失敗しました';
      }

      return success;
    } catch (e) {
      _error = '購入処理中にエラーが発生しました: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 購入履歴をリストア
  Future<bool> restorePurchases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _subscriptionService.restorePurchases();

      if (success) {
        _hasLifetimeAccess = true;
      } else {
        _error = 'リストアする購入履歴が見つかりませんでした';
      }

      return success;
    } catch (e) {
      _error = 'リストア処理中にエラーが発生しました: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Note: _subscriptionService is a global singleton shared across all provider instances.
    // Do not dispose it here as it would cancel the purchase stream for all other instances.
    // The service persists for the app's lifetime and is managed in main.dart.
    super.dispose();
  }
}
