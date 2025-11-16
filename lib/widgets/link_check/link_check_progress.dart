import 'package:flutter/material.dart';

/// Widget to display link check progress
class LinkCheckProgress extends StatelessWidget {
  final int checked;
  final int total;
  final bool isProcessingExternalLinks;

  const LinkCheckProgress({
    super.key,
    required this.checked,
    required this.total,
    this.isProcessingExternalLinks = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPageCheckComplete = total > 0 && checked >= total;
    final showExternalLinksProcessing =
        isPageCheckComplete && isProcessingExternalLinks;

    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  showExternalLinksProcessing
                      ? 'Checking external links...'
                      : 'Checking pages...',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (showExternalLinksProcessing) ...[
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
              ],
            ),
            Text(
              '$checked / $total',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: showExternalLinksProcessing
              ? null // Indeterminate mode for external links
              : (total > 0 ? checked / total : null),
          color: showExternalLinksProcessing ? Colors.orange : null,
        ),
        if (showExternalLinksProcessing) ...[
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
