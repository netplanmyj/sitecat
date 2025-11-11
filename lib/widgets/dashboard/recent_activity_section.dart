import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/link_checker_provider.dart';
import '../../providers/site_provider.dart';
import '../common/empty_state.dart';
import 'result_card.dart';

class RecentActivitySection extends StatelessWidget {
  final VoidCallback? onNavigateToResults;

  const RecentActivitySection({super.key, this.onNavigateToResults});

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkCheckerProvider, child) {
        final allResults = linkCheckerProvider
            .getAllCheckHistory()
            .take(5)
            .toList();

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
            if (allResults.isEmpty)
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
              Consumer<SiteProvider>(
                builder: (context, siteProvider, child) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allResults.length,
                    itemBuilder: (context, index) {
                      final item = allResults[index];
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
                      return DashboardResultCard(
                        site: site,
                        result: item.result,
                      );
                    },
                  );
                },
              ),

            // All Results button
            if (allResults.isNotEmpty)
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
