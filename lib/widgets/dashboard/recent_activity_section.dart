import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/broken_link.dart';
import '../../models/monitoring_result.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/site_provider.dart';
import '../common/empty_state.dart';
import '../monitoring/quick_check_card.dart';
import 'result_card.dart';

// Unified result type for Quick Check and Full Scan
sealed class UnifiedDashboardResult {
  final String siteId;
  final DateTime timestamp;

  UnifiedDashboardResult({required this.siteId, required this.timestamp});
}

class QuickCheckDashboardResult extends UnifiedDashboardResult {
  final MonitoringResult result;

  QuickCheckDashboardResult({required super.siteId, required this.result})
    : super(timestamp: result.timestamp);
}

class FullScanDashboardResult extends UnifiedDashboardResult {
  final LinkCheckResult result;

  FullScanDashboardResult({required super.siteId, required this.result})
    : super(timestamp: result.timestamp);
}

class RecentActivitySection extends StatelessWidget {
  final VoidCallback? onNavigateToResults;

  const RecentActivitySection({super.key, this.onNavigateToResults});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LinkCheckerProvider, MonitoringProvider, SiteProvider>(
      builder: (context, linkChecker, monitoring, siteProvider, child) {
        // Combine Quick Check and Full Scan results
        final allResults = <UnifiedDashboardResult>[];

        // Add Full Scan results
        for (final item in linkChecker.getAllCheckHistory()) {
          allResults.add(
            FullScanDashboardResult(siteId: item.siteId, result: item.result),
          );
        }

        // Add Quick Check results
        for (final item in monitoring.getAllResults()) {
          allResults.add(
            QuickCheckDashboardResult(siteId: item.siteId, result: item.result),
          );
        }

        // Sort by timestamp (newest first) and take 5
        allResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final recentResults = allResults.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),

            // Results list (max 5)
            if (recentResults.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyState(
                    icon: Icons.timeline,
                    title: 'No scan results yet',
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentResults.length,
                itemBuilder: (context, index) {
                  final item = recentResults[index];
                  final site = siteProvider.sites.firstWhere(
                    (s) => s.id == item.siteId,
                    orElse: () => Site(
                      id: item.siteId,
                      userId: '',
                      name: 'Unknown Site',
                      url: '',
                      checkInterval: 60,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return switch (item) {
                    FullScanDashboardResult() => DashboardResultCard(
                      site: site,
                      result: item.result,
                    ),
                    QuickCheckDashboardResult() => QuickCheckCard(
                      site: site,
                      result: item.result,
                    ),
                  };
                },
              ),

            // All Results button
            if (recentResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onNavigateToResults,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'All Results',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
