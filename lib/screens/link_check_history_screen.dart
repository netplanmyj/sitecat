import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/broken_link.dart';
import '../providers/link_checker_provider.dart';

/// Screen to display link check history for a site
class LinkCheckHistoryScreen extends StatefulWidget {
  final Site site;

  const LinkCheckHistoryScreen({super.key, required this.site});

  @override
  State<LinkCheckHistoryScreen> createState() => _LinkCheckHistoryScreenState();
}

class _LinkCheckHistoryScreenState extends State<LinkCheckHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load link check history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkCheckerProvider>().loadCheckHistory(
        widget.site.id,
        limit: 50,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Check History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<LinkCheckerProvider>(
        builder: (context, provider, child) {
          final history = provider.getCheckHistory(widget.site.id);

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No link check history yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Run a link check to see history',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final result = history[index];
                return _buildHistoryItem(context, result, index);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    LinkCheckResult result,
    int index,
  ) {
    final statusColor = result.brokenLinks == 0 ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(context, result),
        onLongPress: () => _confirmDeleteResult(context, result),
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
                          result.brokenLinks == 0
                              ? Icons.check_circle
                              : Icons.link_off,
                          color: statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          result.brokenLinks == 0
                              ? 'All OK'
                              : '${result.brokenLinks} Broken',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Scan completion badge
                  if (!result.scanCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Partial',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
                      'Total Links',
                      result.totalLinks.toString(),
                      Icons.link,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      'Pages',
                      '${result.pagesScanned}/${result.totalPagesInSitemap}',
                      Icons.description,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      'Broken',
                      result.brokenLinks.toString(),
                      Icons.link_off,
                      valueColor: result.brokenLinks > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
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

  void _showDetailDialog(BuildContext context, LinkCheckResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogRow('Total Links', result.totalLinks.toString()),
            const SizedBox(height: 12),
            _buildDialogRow('Internal Links', result.internalLinks.toString()),
            const SizedBox(height: 12),
            _buildDialogRow('External Links', result.externalLinks.toString()),
            const SizedBox(height: 12),
            _buildDialogRow('Broken Links', result.brokenLinks.toString()),
            const SizedBox(height: 12),
            _buildDialogRow(
              'Pages Scanned',
              '${result.pagesScanned}/${result.totalPagesInSitemap}',
            ),
            const SizedBox(height: 12),
            _buildDialogRow(
              'Scan Status',
              result.scanCompleted ? 'Complete' : 'Partial',
            ),
            const SizedBox(height: 12),
            _buildDialogRow(
              'Checked At',
              '${result.timestamp.year}-${result.timestamp.month.toString().padLeft(2, '0')}-${result.timestamp.day.toString().padLeft(2, '0')} '
                  '${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}:${result.timestamp.second.toString().padLeft(2, '0')}',
            ),
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

  Future<void> _confirmDeleteResult(
    BuildContext context,
    LinkCheckResult result,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Result'),
        content: const Text(
          'Are you sure you want to delete this link check result? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted && result.id != null) {
      try {
        final linkChecker = context.read<LinkCheckerProvider>();
        await linkChecker.deleteLinkCheckResult(widget.site.id, result.id!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Result deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete result: $e')),
          );
        }
      }
    }
  }
}
