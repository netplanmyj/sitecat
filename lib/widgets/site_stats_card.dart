import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitoring_provider.dart';

/// Widget to display site monitoring statistics
class SiteStatsCard extends StatelessWidget {
  final String siteId;

  const SiteStatsCard({super.key, required this.siteId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitoringProvider>(
      builder: (context, provider, child) {
        return FutureBuilder(
          future: provider.getStats(siteId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final stats = snapshot.data!;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Uptime',
                            stats.uptimeDisplay,
                            Icons.show_chart,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            'Avg Response',
                            stats.averageResponseTimeDisplay,
                            Icons.timer,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Checks',
                            '${stats.totalChecks}',
                            Icons.history,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            'Status',
                            stats.statusText,
                            Icons.circle,
                            stats.statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
