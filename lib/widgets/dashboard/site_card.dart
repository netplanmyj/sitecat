import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../screens/site_detail_screen.dart';

/// Card widget displaying site information in Dashboard
class DashboardSiteCard extends StatelessWidget {
  final Site site;

  const DashboardSiteCard({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    final isDemoMode = context.watch<AuthProvider>().isDemoMode;

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              site.displayUrl,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            // 定期チェック表示はデモモードでは非表示
            if (!isDemoMode) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Every ${site.checkIntervalDisplay}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ],
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
