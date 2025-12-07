import 'package:flutter/material.dart';
import 'warning_item.dart';

class UrlChangeWarningDialog extends StatelessWidget {
  final String oldUrl;
  final String newUrl;

  const UrlChangeWarningDialog({
    super.key,
    required this.oldUrl,
    required this.newUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('URL Change Detected'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You are changing the site URL. This will affect:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const WarningItem(
            text: 'Previous check results will show as mismatched',
          ),
          const SizedBox(height: 8),
          const WarningItem(text: 'Link check history will be cleared'),
          const SizedBox(height: 8),
          const WarningItem(text: 'You may need to run a new full scan'),
          const SizedBox(height: 16),
          Text(
            'Old URL: $oldUrl',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New URL: $newUrl',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update URL'),
        ),
      ],
    );
  }
}
