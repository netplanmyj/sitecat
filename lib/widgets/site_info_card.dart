import 'package:flutter/material.dart';
import '../models/site.dart';

/// Widget to display basic site information
class SiteInfoCard extends StatelessWidget {
  final Site site;

  const SiteInfoCard({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('URL', site.url),
            const SizedBox(height: 8),
            if (site.sitemapUrl != null) ...[
              _buildInfoRow('Sitemap', site.sitemapUrl!),
              const SizedBox(height: 8),
            ],
            _buildInfoRow('Updated', _formatDate(site.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
