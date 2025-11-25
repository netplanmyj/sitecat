import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/site_provider.dart';
import '../common/empty_state.dart';
import 'site_card.dart';

/// Section widget displaying user's sites on Dashboard
class MySitesSection extends StatelessWidget {
  final VoidCallback? onNavigateToSites;

  const MySitesSection({super.key, this.onNavigateToSites});

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteProvider>(
      builder: (context, siteProvider, child) {
        final sites = siteProvider.sites.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'My Sites',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),

            // Site cards (max 5)
            if (sites.isEmpty)
              const EmptyState(
                icon: Icons.web_asset,
                title: 'No sites added yet',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sites.length,
                itemBuilder: (context, index) {
                  final site = sites[index];
                  return SiteCard(site: site);
                },
              ),

            // All Sites button
            if (sites.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onNavigateToSites,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      'All Sites (${siteProvider.sites.length})',
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
