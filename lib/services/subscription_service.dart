import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

/// In-App Purchase管理サービス
///
/// 買い切り版（¥1,220）の購入・リストア・状態管理を担当
class SubscriptionService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  /// 買い切り版の商品ID
  static const String lifetimeProductId = 'sitecat.lifetime.basic';

  /// 購入状態のストリーム
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 初期化
  Future<void> initialize() async {
    // In-App Purchaseが利用可能かチェック
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      _logger.e('In-App Purchase is not available on this device');
      return;
    }

    // 購入ストリームをリッスン
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );
  }

  /// 破棄
  void dispose() {
    _subscription?.cancel();
  }

  /// 買い切り版を購入済みか確認
  ///
  /// 1. Firestoreキャッシュを確認
  /// 2. キャッシュがない場合、StoreKitで確認
  /// 3. 結果をFirestoreに保存
  Future<bool> hasLifetimeAccess() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Firestoreのキャッシュを確認
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('lifetime')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isActive'] == true) {
          _logger.d('Lifetime access found in Firestore cache');
          return true;
        }
      }

      // StoreKitで購入履歴を確認
      await _inAppPurchase.restorePurchases();

      // 再度Firestoreを確認（リストア処理で更新される可能性がある）
      final updatedDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('lifetime')
          .get();

      if (updatedDoc.exists) {
        final data = updatedDoc.data();
        return data != null && data['isActive'] == true;
      }

      return false;
    } catch (e) {
      _logger.e('Error checking lifetime access: $e');
      return false;
    }
  }

  /// 買い切り版を購入
  Future<bool> purchaseLifetimeAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('User not authenticated');
      return false;
    }

    try {
      // 商品情報を取得
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails({lifetimeProductId});

      if (response.notFoundIDs.isNotEmpty) {
        _logger.e('Product not found: $lifetimeProductId');
        return false;
      }

      if (response.error != null) {
        _logger.e('Error querying product: ${response.error}');
        return false;
      }

      final productDetails = response.productDetails.first;

      // 購入リクエスト作成
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // 購入処理を開始
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return success;
    } catch (e) {
      _logger.e('Error purchasing lifetime access: $e');
      return false;
    }
  }

  /// 購入履歴をリストア
  Future<bool> restorePurchases() async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('User not authenticated');
      return false;
    }

    try {
      await _inAppPurchase.restorePurchases();

      // リストア後、Firestoreを確認
      final hasAccess = await hasLifetimeAccess();

      if (hasAccess) {
        _logger.i('Purchases restored successfully');
      } else {
        _logger.w('No purchases found to restore');
      }

      return hasAccess;
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
      return false;
    }
  }

  /// 商品情報を取得
  Future<ProductDetails?> getProductDetails() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails({lifetimeProductId});

      if (response.notFoundIDs.isNotEmpty) {
        _logger.e('Product not found: $lifetimeProductId');
        return null;
      }

      if (response.error != null) {
        _logger.e('Error querying product: ${response.error}');
        return null;
      }

      return response.productDetails.first;
    } catch (e) {
      _logger.e('Error getting product details: $e');
      return null;
    }
  }

  /// 購入ストリームの更新を処理
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 購入処理中
        _logger.d('Purchase pending: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // 購入エラー
        _logger.e('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 購入成功またはリストア成功
        await _handleSuccessfulPurchase(purchaseDetails);
      }

      // 購入処理が完了したら完了マークを付ける
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// 購入成功時の処理
  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('User not authenticated during purchase');
      return;
    }

    try {
      // Firestoreに購入情報を保存
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('lifetime')
          .set({
            'productId': purchaseDetails.productID,
            'purchaseDate': FieldValue.serverTimestamp(),
            'isActive': true,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'transactionId': purchaseDetails.purchaseID,
            'verificationData':
                purchaseDetails.verificationData.serverVerificationData,
          });

      _logger.i('Purchase saved to Firestore: ${purchaseDetails.productID}');
    } catch (e) {
      _logger.e('Error saving purchase to Firestore: $e');
    }
  }

  /// 購入ストリーム完了時の処理
  void _onPurchaseDone() {
    _logger.d('Purchase stream done');
  }

  /// 購入ストリームエラー時の処理
  void _onPurchaseError(dynamic error) {
    _logger.e('Purchase stream error: $error');
  }
}
