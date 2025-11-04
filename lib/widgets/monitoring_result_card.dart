import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import '../providers/monitoring_provider.dart';
import '../screens/monitoring_history_screen.dart';

/// Widget for displaying latest monitoring result
class MonitoringResultCard extends StatelessWidget {
  final Site site;

  const MonitoringResultCard({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitoringProvider>(
      builder: (context, provider, child) {
        final latestResult = provider.getLatestResult(site.id);

        if (latestResult == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No check results yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Check Result',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildStatusBadge(latestResult),
                const SizedBox(height: 12),
                _buildResultRow(
                  'Status Code',
                  latestResult.statusCode.toString(),
                ),
                const SizedBox(height: 8),
                _buildResultRow(
                  'Response Time',
                  '${latestResult.responseTime}ms',
                ),
                const SizedBox(height: 8),
                _buildResultRow(
                  'Checked At',
                  _formatDateTime(latestResult.timestamp),
                ),
                if (latestResult.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            latestResult.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MonitoringHistoryScreen(site: site),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(MonitoringResult result) {
    Color color;
    IconData icon;
    String text;

    if (result.isUp) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'OK';
    } else {
      color = Colors.red;
      icon = Icons.error;
      text = 'Error';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
