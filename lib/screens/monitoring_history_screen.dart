import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/monitoring_result.dart';
import '../providers/monitoring_provider.dart';

/// Screen to display monitoring history for a site
class MonitoringHistoryScreen extends StatefulWidget {
  final Site site;

  const MonitoringHistoryScreen({super.key, required this.site});

  @override
  State<MonitoringHistoryScreen> createState() =>
      _MonitoringHistoryScreenState();
}

class _MonitoringHistoryScreenState extends State<MonitoringHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to monitoring results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().listenToSiteResults(
        widget.site.id,
        limit: 100,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<MonitoringProvider>(
        builder: (context, provider, child) {
          final results = provider.getSiteResults(widget.site.id);

          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No check history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Perform a site check to see history',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary Card
              _buildSummaryCard(results),
              const SizedBox(height: 8),

              // History List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _buildHistoryItem(context, result, index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(List<MonitoringResult> results) {
    final totalChecks = results.length;
    final successfulChecks = results.where((r) => r.isUp).length;
    final failedChecks = totalChecks - successfulChecks;
    final uptime = totalChecks > 0
        ? ((successfulChecks / totalChecks) * 100).toStringAsFixed(1)
        : '0.0';
    final avgResponseTime = results.isNotEmpty
        ? (results.map((r) => r.responseTime).reduce((a, b) => a + b) /
                  results.length)
              .round()
        : 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Checks',
                    totalChecks.toString(),
                    Icons.fact_check,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Uptime',
                    '$uptime%',
                    Icons.trending_up,
                    double.parse(uptime) >= 95 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Successful',
                    successfulChecks.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Failed',
                    failedChecks.toString(),
                    Icons.error,
                    failedChecks > 0 ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Avg Response Time',
              '${avgResponseTime}ms',
              Icons.speed,
              avgResponseTime < 1000 ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    MonitoringResult result,
    int index,
  ) {
    final isSuccess = result.isUp;
    final statusColor = isSuccess ? Colors.green : Colors.red;
    final responseTimeColor = result.responseTime < 1000
        ? Colors.green
        : result.responseTime < 3000
        ? Colors.orange
        : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(context, result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSuccess ? Icons.check_circle : Icons.error,
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSuccess ? 'Up' : 'Down',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Timestamp
                  Text(
                    _formatRelativeTime(result.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Details Row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      'Status Code',
                      result.statusCode.toString(),
                      Icons.code,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      'Response Time',
                      '${result.responseTime}ms',
                      Icons.speed,
                      valueColor: responseTimeColor,
                    ),
                  ),
                ],
              ),

              // Error message if exists
              if (result.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showDetailDialog(BuildContext context, MonitoringResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow('Status', result.isUp ? 'Up ✓' : 'Down ✗'),
            const SizedBox(height: 12),
            _buildDialogRow('Status Code', result.statusCode.toString()),
            const SizedBox(height: 12),
            _buildDialogRow('Response Time', '${result.responseTime}ms'),
            const SizedBox(height: 12),
            _buildDialogRow(
              'Checked At',
              '${result.timestamp.year}-${result.timestamp.month.toString().padLeft(2, '0')}-${result.timestamp.day.toString().padLeft(2, '0')} '
                  '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}:${result.timestamp.second.toString().padLeft(2, '0')}',
            ),
            if (result.error != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Error:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(result.error!, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }
}
