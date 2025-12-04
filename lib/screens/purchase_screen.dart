import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/site_provider.dart';
import '../providers/link_checker_provider.dart';
import '../providers/monitoring_provider.dart';

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
      appBar: AppBar(title: const Text('Upgrade to Premium')),
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
              'You are using\nPremium',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enjoy all premium features',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
            // Title
            const Text(
              'SiteCat Premium',
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
              'One-time purchase (Lifetime access)',
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

            // Purchase button
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (!mounted) return;
                      final siteProvider = context.read<SiteProvider>();
                      final linkCheckerProvider = context
                          .read<LinkCheckerProvider>();
                      final monitoringProvider = context
                          .read<MonitoringProvider>();
                      final messenger = ScaffoldMessenger.of(context);

                      final success = await provider.purchaseLifetime();
                      if (!mounted) return;

                      if (success) {
                        // Update all providers with new premium status
                        final isPremium = provider.hasLifetimeAccess;
                        siteProvider.setHasLifetimeAccess(isPremium);
                        linkCheckerProvider.setHasLifetimeAccess(isPremium);
                        monitoringProvider.setHasLifetimeAccess(isPremium);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Purchase completed!'),
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
                'Purchase',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Restore button
            TextButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (!mounted) return;
                      final siteProvider = context.read<SiteProvider>();
                      final linkCheckerProvider = context
                          .read<LinkCheckerProvider>();
                      final monitoringProvider = context
                          .read<MonitoringProvider>();
                      final messenger = ScaffoldMessenger.of(context);

                      final success = await provider.restorePurchases();
                      if (!mounted) return;

                      if (success) {
                        // Update all providers with restored premium status
                        final isPremium = provider.hasLifetimeAccess;
                        siteProvider.setHasLifetimeAccess(isPremium);
                        linkCheckerProvider.setHasLifetimeAccess(isPremium);
                        monitoringProvider.setHasLifetimeAccess(isPremium);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Purchases restored'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('No purchases found to restore'),
                          ),
                        );
                      }
                    },
              child: const Text('Restore Purchases'),
            ),
            const SizedBox(height: 24),

            // Terms and Privacy Policy
            const Text(
              'By purchasing, you agree to our Terms of Service and Privacy Policy.',
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
              'Premium Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFeatureRow(
              Icons.web,
              'Site Registration',
              '3 sites',
              '30 sites',
            ),
            const Divider(),
            _buildFeatureRow(
              Icons.pause_circle,
              'Full Scan Pause/Resume',
              '×',
              '○',
            ),
            const Divider(),
            _buildFeatureRow(
              Icons.filter_alt,
              'Exclude Path Settings',
              '×',
              '○',
            ),
            const Divider(),
            _buildFeatureRow(
              Icons.history,
              'History Display',
              '10 each',
              '50 each',
            ),
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
