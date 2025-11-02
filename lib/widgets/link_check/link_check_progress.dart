import 'package:flutter/material.dart';

/// Widget to display link check progress
class LinkCheckProgress extends StatelessWidget {
  final int checked;
  final int total;

  const LinkCheckProgress({
    super.key,
    required this.checked,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Checking pages...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            Text(
              '$checked / $total',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: total > 0 ? checked / total : null),
      ],
    );
  }
}
