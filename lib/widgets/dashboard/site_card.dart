import 'package:flutter/material.dart';
import '../../models/site.dart';
import '../../screens/site_detail_screen.dart';

/// Card widget displaying site information
/// Can be used in both Dashboard and Sites screen
class SiteCard extends StatelessWidget {
  final Site site;
  final bool showLastChecked;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SiteCard({
    super.key,
    required this.site,
    this.showLastChecked = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.language, color: Colors.blue.shade700),
        ),
        title: Text(
          site.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: showLastChecked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.displayUrl,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last: ${site.lastCheckedDisplay}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(
                site.displayUrl,
                style: TextStyle(color: Colors.grey.shade600),
              ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap:
            onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SiteDetailScreen(site: site),
                ),
              );
            },
      ),
    );
  }
}

/// Legacy name for backward compatibility
@Deprecated('Use SiteCard instead')
class DashboardSiteCard extends SiteCard {
  const DashboardSiteCard({super.key, required super.site});
}
