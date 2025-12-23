import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/subscription_service.dart';
import '../constants/error_messages.dart';

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
  String get price => _productDetails?.price ?? '¥1,200';

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
      _error = '${ErrorMessages.failedToLoadSubscriptionInfo} $e';
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
      _error = '${ErrorMessages.failedToCheckAccessRights} $e';
      notifyListeners();
    }
  }

  /// 商品情報を読み込み
  Future<void> _loadProductDetails() async {
    try {
      _productDetails = await _subscriptionService.getProductDetails();
      notifyListeners();
    } catch (e) {
      _error = '${ErrorMessages.failedToLoadProductDetails} $e';
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
        // 購入処理開始後、StoreKit の非同期処理完了を待つ
        // _onPurchaseUpdate() → saveLifetimePurchase → Firestore 保存が完了するまでポーリング
        await _waitForPurchaseCompletion();
      } else {
        _error = '${ErrorMessages.purchaseFailed} Payment was not completed.';
      }

      return success;
    } catch (e) {
      _error = '${ErrorMessages.purchaseErrorOccurred} $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 購入完了を待つ（最大10秒間ポーリング）
  Future<void> _waitForPurchaseCompletion() async {
    const maxAttempts = 10; // 10回試行
    const delayBetweenAttempts = Duration(seconds: 1);

    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(delayBetweenAttempts);
      await _checkLifetimeAccess();

      if (_hasLifetimeAccess) {
        // 購入が確認できたら即座に終了
        return;
      }
    }

    // 10秒経っても購入が確認できない場合は警告
    // （通常は数秒以内に完了するはず）
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
        _error = ErrorMessages.noRestorablePurchases;
      }

      return success;
    } catch (e) {
      _error = '${ErrorMessages.restoreErrorOccurred} $e';
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
