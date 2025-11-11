import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/site.dart';
import '../../providers/monitoring_provider.dart';
import '../countdown_timer.dart';

class QuickCheckSection extends StatelessWidget {
  final Site site;
  final VoidCallback onQuickCheck;

  const QuickCheckSection({
    super.key,
    required this.site,
    required this.onQuickCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<MonitoringProvider>(
          builder: (context, monitoringProvider, child) {
            final isCheckingSite = monitoringProvider.isChecking(site.id);
            final canCheckSite = monitoringProvider.canCheckSite(site.id);
            final timeUntilNext = monitoringProvider.getTimeUntilNextCheck(
              site.id,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.speed, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Quick Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '⚡ Site status only (~3 seconds)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Quick Check button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (isCheckingSite || !canCheckSite)
                        ? null
                        : onQuickCheck,
                    icon: isCheckingSite
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.speed, size: 20),
                    label: const Text('Start Check'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                // Countdown timer (rate limit for checks)
                if (timeUntilNext != null) ...[
                  const SizedBox(height: 8),
                  CountdownTimer(
                    initialDuration: timeUntilNext,
                    onComplete: () {
                      // Trigger rebuild by notifying parent if needed
                      // Parent should use setState when this completes
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
