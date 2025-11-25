import 'package:flutter/material.dart';
import '../../models/site.dart';
import '../../screens/site_detail_screen.dart';

/// Card widget displaying site information in Dashboard
class DashboardSiteCard extends StatelessWidget {
  final Site site;

  const DashboardSiteCard({super.key, required this.site});

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
        subtitle: Text(
          site.displayUrl,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
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
