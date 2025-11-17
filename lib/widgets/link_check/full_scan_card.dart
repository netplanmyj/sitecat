import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../models/site.dart';
import '../../utils/date_formatter.dart';

/// Reusable Full Scan result card for All Results and Dashboard
class FullScanCard extends StatelessWidget {
  final Site site;
  final LinkCheckResult result;
  final VoidCallback onTap;

  const FullScanCard({
    super.key,
    required this.site,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with timestamp
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
                            Expanded(
                              child: Text(
                                site.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormatter.formatRelativeTime(
                                result.timestamp,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                site.url,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.purple.shade200,
                                ),
                              ),
                              child: Text(
                                'Full Scan',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.link,
                          '${result.totalLinks}',
                          null,
                          Colors.blue,
                        ),
                        _buildStatItem(
                          Icons.link_off,
                          '${result.brokenLinks}',
                          null,
                          result.brokenLinks > 0 ? Colors.red : Colors.green,
                        ),
                        _buildStatItem(
                          Icons.description,
                          '${result.pagesScanned}/${result.totalPagesInSitemap}',
                          null,
                          result.scanCompleted ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
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
    String? label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        if (label != null)
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
      ],
    );
  }
}
