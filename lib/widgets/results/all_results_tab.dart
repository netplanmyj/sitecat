import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/broken_link.dart';
import '../../models/monitoring_result.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/monitoring_provider.dart';
import '../../providers/site_provider.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/common/empty_state.dart';
import '../../screens/broken_links_screen.dart';
import '../monitoring/quick_check_card.dart';

// Unified result type for Quick Check and Full Scan
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
        // Combine Quick Check and Full Scan results
        final allResults = <UnifiedResult>[];

        // Add Full Scan results
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
              FullScanResult() => _buildFullScanCard(
                context,
                item,
                site,
                linkChecker,
              ),
            };
          },
        );
      },
    );
  }

  Widget _buildFullScanCard(
    BuildContext context,
    FullScanResult item,
    Site site,
    LinkCheckerProvider linkChecker,
  ) {
    final result = item.result;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          // Load broken links and navigate
          final brokenLinks = await linkChecker.getBrokenLinksForResult(
            site.id,
            result.id!,
          );
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrokenLinksScreen(
                  site: site,
                  brokenLinks: brokenLinks,
                  result: result,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: result.brokenLinks > 0
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    child: Icon(
                      result.brokenLinks > 0
                          ? Icons.link_off
                          : Icons.check_circle,
                      size: 18,
                      color: result.brokenLinks > 0
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              site.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                ),
                              ),
                              child: Text(
                                'Full Scan',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          site.url,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    result.scanCompleted
                        ? Icons.check_circle
                        : Icons.incomplete_circle,
                    color: result.scanCompleted ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.link,
                    '${result.totalLinks}',
                    'Links',
                    Colors.blue,
                  ),
                  _buildStatItem(
                    Icons.link_off,
                    '${result.brokenLinks}',
                    'Broken',
                    result.brokenLinks > 0 ? Colors.red : Colors.green,
                  ),
                  _buildStatItem(
                    Icons.description,
                    '${result.pagesScanned}/${result.totalPagesInSitemap}',
                    'Pages',
                    result.scanCompleted ? Colors.green : Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Timestamp
              Text(
                DateFormatter.formatRelativeTime(result.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
