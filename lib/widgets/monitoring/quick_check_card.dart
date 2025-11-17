import 'package:flutter/material.dart';
import '../../models/monitoring_result.dart';
import '../../models/site.dart';
import '../../utils/date_formatter.dart';

/// Reusable Quick Check result card for All Results and Dashboard
class QuickCheckCard extends StatelessWidget {
  final Site site;
  final MonitoringResult result;

  const QuickCheckCard({super.key, required this.site, required this.result});

  @override
  Widget build(BuildContext context) {
    final isUp = result.isUp;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  backgroundColor: isUp
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    isUp ? Icons.check_circle : Icons.error,
                    size: 18,
                    color: isUp ? Colors.green.shade700 : Colors.red.shade700,
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
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              'Quick Check',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
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
                  Icons.speed,
                  '${result.responseTime}ms',
                  'Response',
                  result.responseTime < 1000 ? Colors.green : Colors.orange,
                ),
                _buildStatItem(
                  Icons.code,
                  '${result.statusCode}',
                  'Status',
                  result.statusCode >= 200 && result.statusCode < 300
                      ? Colors.green
                      : Colors.orange,
                ),
                _buildStatItem(
                  isUp ? Icons.check_circle : Icons.error,
                  isUp ? 'UP' : 'DOWN',
                  'Status',
                  isUp ? Colors.green : Colors.red,
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
