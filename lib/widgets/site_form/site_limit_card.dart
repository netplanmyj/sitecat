import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

class SiteLimitCard extends StatelessWidget {
  final int siteCount;
  final int siteLimit;
  final VoidCallback onBackPressed;

  const SiteLimitCard({
    super.key,
    required this.siteCount,
    required this.siteLimit,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              AppConstants.siteLimitReachedMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              'Current sites: $siteCount / $siteLimit',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBackPressed,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Sites'),
            ),
          ],
        ),
      ),
    );
  }
}
