import 'package:flutter/material.dart';

/// A reusable widget to display an empty state with an icon, title, and optional subtitle
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 64,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
