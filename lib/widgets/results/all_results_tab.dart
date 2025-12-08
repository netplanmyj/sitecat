import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/broken_link.dart';
import '../../models/monitoring_result.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/site_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../screens/broken_links_screen.dart';
import '../monitoring/quick_check_card.dart';
import '../link_check/full_scan_card.dart';

// Unified result type for Quick Check and Site Scan
sealed class UnifiedResult {
  final String siteId;
  final DateTime timestamp;

  UnifiedResult({required this.siteId, required this.timestamp});
}

class QuickCheckResult extends UnifiedResult {
  final MonitoringResult result;

  QuickCheckResult({required super.siteId, required this.result})
    : super(timestamp: result.timestamp);
}

class FullScanResult extends UnifiedResult {
  final LinkCheckResult result;

  FullScanResult({required super.siteId, required this.result})
    : super(timestamp: result.timestamp);
}

class AllResultsTab extends StatelessWidget {
  const AllResultsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LinkCheckerProvider, MonitoringProvider, SiteProvider>(
      builder: (context, linkChecker, monitoring, siteProvider, child) {
        // Combine Quick Check and Site Scan results
        final allResults = <UnifiedResult>[];

        // Add Site Scan results
        for (final item in linkChecker.getAllCheckHistory()) {
          allResults.add(
            FullScanResult(siteId: item.siteId, result: item.result),
          );
        }

        // Add Quick Check results
        for (final item in monitoring.getAllResults()) {
          allResults.add(
            QuickCheckResult(siteId: item.siteId, result: item.result),
          );
        }

        // Sort by timestamp (newest first)
        allResults.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (allResults.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.assessment,
                title: 'No results yet',
                subtitle: 'Run a scan or check to see results',
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allResults.length,
          itemBuilder: (context, index) {
            final item = allResults[index];
            final site = siteProvider.sites.firstWhere(
              (s) => s.id == item.siteId,
              orElse: () => Site(
                id: item.siteId,
                userId: '',
                url: 'Unknown',
                name: 'Unknown Site',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            return switch (item) {
              QuickCheckResult() => QuickCheckCard(
                site: site,
                result: item.result,
              ),
              FullScanResult() => FullScanCard(
                site: site,
                result: item.result,
                onTap: () async {
                  final brokenLinks = await linkChecker.getBrokenLinksForResult(
                    site.id,
                    item.result.id!,
                  );
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BrokenLinksScreen(
                          site: site,
                          brokenLinks: brokenLinks,
                          result: item.result,
                        ),
                      ),
                    );
                  }
                },
              ),
            };
          },
        );
      },
    );
  }
}
