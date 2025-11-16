import 'package:flutter/material.dart';

/// Widget to display link check progress
class LinkCheckProgress extends StatelessWidget {
  final int checked;
  final int total;
  final bool isProcessingExternalLinks;
  final int externalLinksChecked;
  final int externalLinksTotal;

  const LinkCheckProgress({
    super.key,
    required this.checked,
    required this.total,
    this.isProcessingExternalLinks = false,
    this.externalLinksChecked = 0,
    this.externalLinksTotal = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Show links checking when there are links (keep display after completion)
    final showLinksChecking = externalLinksTotal > 0;

    return Column(
      children: [
        const SizedBox(height: 16),
        // Page scanning progress
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Checking pages...',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Text(
              '$checked / $total',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: total > 0 ? checked / total : null),

        // Links checking progress (internal + external)
        if (showLinksChecking) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Checking links...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                '$externalLinksChecked / $externalLinksTotal',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: externalLinksTotal > 0
                ? externalLinksChecked / externalLinksTotal
                : null,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few minutes...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
