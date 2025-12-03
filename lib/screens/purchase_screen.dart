import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

/// 買い切り版購入画面
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  @override
  void initState() {
    super.initState();
    // 画面表示時に商品情報を読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレミアム版にアップグレード')),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.hasLifetimeAccess) {
            return _buildAlreadyPurchasedView(context);
          }

          return _buildPurchaseView(context, provider);
        },
      ),
    );
  }

  /// 購入済みの場合の表示
  Widget _buildAlreadyPurchasedView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'プレミアム版を\nご利用中です',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'すべての機能をお楽しみいただけます',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  /// 購入画面の表示
  Widget _buildPurchaseView(
    BuildContext context,
    SubscriptionProvider provider,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイトル
            const Text(
              'SiteCat プレミアム版',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              provider.price,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '買い切り（永続利用）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 機能比較表
            _buildFeatureComparison(),
            const SizedBox(height: 32),

            // エラーメッセージ
            if (provider.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 購入ボタン
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.purchaseLifetime();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('購入が完了しました！'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '購入する',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // リストアボタン
            TextButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.restorePurchases();
                      if (mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('購入履歴をリストアしました'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('リストアする購入履歴が見つかりませんでした'),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('購入履歴をリストア'),
            ),
            const SizedBox(height: 24),

            // 利用規約・プライバシーポリシー
            const Text(
              '購入することで、利用規約とプライバシーポリシーに同意したものとみなされます。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// 機能比較表
  Widget _buildFeatureComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プレミアム版の機能',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(Icons.web, 'サイト登録', '1個', '無制限'),
            const Divider(),
            _buildFeatureRow(Icons.pause_circle, 'Full Scan中断・再開', '×', '○'),
            const Divider(),
            _buildFeatureRow(Icons.filter_alt, '除外パス設定', '×', '○'),
            const Divider(),
            _buildFeatureRow(Icons.history, '履歴表示', '各10件', '各50件'),
          ],
        ),
      ),
    );
  }

  /// 機能比較行
  Widget _buildFeatureRow(
    IconData icon,
    String feature,
    String free,
    String premium,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(feature, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
