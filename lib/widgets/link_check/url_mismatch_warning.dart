import 'package:flutter/material.dart';

/// Widget to display URL mismatch warning
class UrlMismatchWarning extends StatelessWidget {
  final String checkedUrl;
  final String currentUrl;

  const UrlMismatchWarning({
    super.key,
    required this.checkedUrl,
    required this.currentUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URL Mismatch Detected',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This result was checked for a different URL:',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  checkedUrl,
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Current site URL: $currentUrl',
                  style: TextStyle(color: Colors.amber.shade700, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
