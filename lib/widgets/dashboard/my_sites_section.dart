import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/site_provider.dart';
import '../../screens/site_form_screen.dart';
import '../../screens/site_detail_screen.dart';
import '../../models/site.dart';
import '../../utils/dialogs.dart';
import '../common/empty_state.dart';
import 'site_card.dart';

/// Section widget displaying user's sites on Dashboard
class MySitesSection extends StatefulWidget {
  final VoidCallback? onNavigateToSites;

  const MySitesSection({super.key, this.onNavigateToSites});

  @override
  State<MySitesSection> createState() => _MySitesSectionState();
}

class _MySitesSectionState extends State<MySitesSection> {
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
                  return SiteCard(
                    site: site,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _handleMenuAction(context, value, site, siteProvider),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 20),
                              SizedBox(width: 8),
                              Text('View'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
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
                    onPressed: widget.onNavigateToSites,
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

  void _handleMenuAction(
    BuildContext context,
    String action,
    Site site,
    SiteProvider siteProvider,
  ) {
    switch (action) {
      case 'view':
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SiteDetailScreen(site: site),
            ),
          );
        }
        break;

      case 'edit':
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => SiteFormScreen(site: site)),
          );
        }
        break;

      case 'delete':
        if (mounted) {
          _showDeleteConfirmation(context, site, siteProvider);
        }
        break;
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Site site,
    SiteProvider siteProvider,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Dialogs.confirm(
      context,
      title: 'Delete Site',
      message: 'Are you sure you want to delete "${site.name}"?',
      okText: 'Delete',
      cancelText: 'Cancel',
    ).then((confirmed) async {
      if (!confirmed) return;
      final success = await siteProvider.deleteSite(site.id);
      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${site.name} deleted')),
        );
      }
    });
  }
}
