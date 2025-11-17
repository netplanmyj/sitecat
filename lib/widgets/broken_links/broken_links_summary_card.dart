import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../utils/date_formatter.dart';

class BrokenLinksSummaryCard extends StatelessWidget {
  final Site site;
  final LinkCheckResult result;

  const BrokenLinksSummaryCard({
    super.key,
    required this.site,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              site.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Scanned ${DateFormatter.formatRelativeTime(result.timestamp)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Links',
                  result.totalLinks.toString(),
                  Icons.link,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Internal',
                  result.internalLinks.toString(),
                  Icons.home,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'External',
                  result.externalLinks.toString(),
                  Icons.public,
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Broken',
                  result.brokenLinks.toString(),
                  Icons.link_off,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
