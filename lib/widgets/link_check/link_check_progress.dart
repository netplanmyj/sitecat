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
    final isPageCheckComplete = total > 0 && checked >= total;
    final showExternalLinksProcessing =
        isPageCheckComplete && isProcessingExternalLinks;

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

        // External links checking progress (shown when processing)
        if (showExternalLinksProcessing) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Checking links...',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ],
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
