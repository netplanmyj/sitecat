import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sitecat/providers/subscription_provider.dart';
import 'package:sitecat/services/subscription_service.dart';

import 'subscription_provider_test.mocks.dart';

@GenerateMocks(
  [SubscriptionService],
  customMocks: [MockSpec<ProductDetails>(as: #MockProductDetailsCustom)],
)
void main() {
  late MockSubscriptionService mockSubscriptionService;
  late SubscriptionProvider provider;

  setUp(() {
    mockSubscriptionService = MockSubscriptionService();
    provider = SubscriptionProvider(mockSubscriptionService);
  });

  group('SubscriptionProvider', () {
    test('初期状態では買い切り版アクセス権がfalse', () {
      expect(provider.hasLifetimeAccess, false);
      expect(provider.isLoading, false);
      expect(provider.error, null);
    });

    test('initialize()呼び出し時、サービスを初期化し状態を確認', () async {
      // Arrange
      when(mockSubscriptionService.initialize()).thenAnswer((_) async => {});
      when(
        mockSubscriptionService.hasLifetimeAccess(),
      ).thenAnswer((_) async => true);
      when(
        mockSubscriptionService.getProductDetails(),
      ).thenAnswer((_) async => null);

      // Act
      await provider.initialize();

      // Assert
      verify(mockSubscriptionService.initialize()).called(1);
      verify(mockSubscriptionService.hasLifetimeAccess()).called(1);
      verify(mockSubscriptionService.getProductDetails()).called(1);
      expect(provider.hasLifetimeAccess, true);
      expect(provider.isLoading, false);
    });

    test('initialize()でエラー発生時、エラーメッセージを設定', () async {
      // Arrange
      when(mockSubscriptionService.initialize()).thenThrow(Exception('初期化エラー'));

      // Act
      await provider.initialize();

      // Assert
      expect(
        provider.error,
        contains('Failed to load subscription information:'),
      );
      expect(provider.isLoading, false);
    });

    test('purchaseLifetime()成功時、hasLifetimeAccessがtrueになる', () async {
      // Arrange
      when(
        mockSubscriptionService.purchaseLifetimeAccess(),
      ).thenAnswer((_) async => true);
      when(
        mockSubscriptionService.hasLifetimeAccess(),
      ).thenAnswer((_) async => true);

      // Act
      final result = await provider.purchaseLifetime();

      // Assert
      expect(result, true);
      expect(provider.hasLifetimeAccess, true);
      expect(provider.error, null);
      expect(provider.isLoading, false);
    });

    test('purchaseLifetime()失敗時、エラーメッセージを設定', () async {
      // Arrange
      when(
        mockSubscriptionService.purchaseLifetimeAccess(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await provider.purchaseLifetime();

      // Assert
      expect(result, false);
      expect(provider.error, contains('Purchase failed:'));
      expect(provider.isLoading, false);
    });

    test('purchaseLifetime()で例外発生時、エラーメッセージを設定', () async {
      // Arrange
      when(
        mockSubscriptionService.purchaseLifetimeAccess(),
      ).thenThrow(Exception('購入処理エラー'));

      // Act
      final result = await provider.purchaseLifetime();

      // Assert
      expect(result, false);
      expect(provider.error, contains('An error occurred during purchase:'));
      expect(provider.isLoading, false);
    });

    test('restorePurchases()成功時、hasLifetimeAccessがtrueになる', () async {
      // Arrange
      when(
        mockSubscriptionService.restorePurchases(),
      ).thenAnswer((_) async => true);

      // Act
      final result = await provider.restorePurchases();

      // Assert
      expect(result, true);
      expect(provider.hasLifetimeAccess, true);
      expect(provider.error, null);
      expect(provider.isLoading, false);
    });

    test('restorePurchases()失敗時、エラーメッセージを設定', () async {
      // Arrange
      when(
        mockSubscriptionService.restorePurchases(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await provider.restorePurchases();

      // Assert
      expect(result, false);
      expect(provider.error, 'No restorable purchases found.');
      expect(provider.isLoading, false);
    });

    test('restorePurchases()で例外発生時、エラーメッセージを設定', () async {
      // Arrange
      when(
        mockSubscriptionService.restorePurchases(),
      ).thenThrow(Exception('リストアエラー'));

      // Act
      final result = await provider.restorePurchases();

      // Assert
      expect(result, false);
      expect(provider.error, contains('An error occurred during restoration:'));
      expect(provider.isLoading, false);
    });

    test('clearError()でエラーメッセージをクリア', () async {
      // Arrange
      when(
        mockSubscriptionService.purchaseLifetimeAccess(),
      ).thenAnswer((_) async => false);
      await provider.purchaseLifetime();
      expect(provider.error, isNotNull);

      // Act
      provider.clearError();

      // Assert
      expect(provider.error, null);
    });

    test('商品情報が取得できた場合、priceを返す', () async {
      // Arrange
      final mockProduct = MockProductDetailsCustom();
      when(mockProduct.price).thenReturn('¥1,200');

      when(mockSubscriptionService.initialize()).thenAnswer((_) async => {});
      when(
        mockSubscriptionService.hasLifetimeAccess(),
      ).thenAnswer((_) async => false);
      when(
        mockSubscriptionService.getProductDetails(),
      ).thenAnswer((_) async => mockProduct);

      // Act
      await provider.initialize();

      // Assert
      expect(provider.price, '¥1,200');
    });

    test('商品情報が取得できない場合、デフォルト価格を返す', () {
      expect(provider.price, '¥1,200');
    });
  });
}
