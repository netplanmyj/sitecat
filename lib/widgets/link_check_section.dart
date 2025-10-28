import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../models/broken_link.dart';
import '../providers/link_checker_provider.dart';

/// Widget for link checking section
class LinkCheckSection extends StatelessWidget {
  final Site site;
  final VoidCallback onCheckComplete;
  final Function(String error) onCheckError;
  final Function(
    Site site,
    List<BrokenLink> brokenLinks,
    LinkCheckResult result,
  )
  onViewBrokenLinks;

  const LinkCheckSection({
    super.key,
    required this.site,
    required this.onCheckComplete,
    required this.onCheckError,
    required this.onViewBrokenLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkChecker, child) {
        final state = linkChecker.getCheckState(site.id);
        final result = linkChecker.getCachedResult(site.id);
        final (checked, total) = linkChecker.getProgress(site.id);
        final brokenLinks = linkChecker.getCachedBrokenLinks(site.id);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link_off, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Link Check',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (state == LinkCheckState.checking)
                      Text(
                        '$checked / $total',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Check button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state == LinkCheckState.checking
                        ? null
                        : () => _checkLinks(context),
                    icon: state == LinkCheckState.checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      state == LinkCheckState.checking
                          ? 'Checking...'
                          : 'Check Links',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),

                // Progress indicator
                if (state == LinkCheckState.checking) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: total > 0 ? checked / total : null,
                  ),
                ],

                // Results summary
                if (result != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLinkStatCard(
                          'Total Links',
                          result.totalLinks.toString(),
                          Icons.link,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLinkStatCard(
                          'Broken',
                          result.brokenLinks.toString(),
                          Icons.link_off,
                          result.brokenLinks > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (brokenLinks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          onViewBrokenLinks(site, brokenLinks, result),
                      icon: const Icon(Icons.list),
                      label: const Text('View Broken Links'),
                    ),
                  ],
                ],

                // Error message
                if (state == LinkCheckState.error) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            linkChecker.getError(site.id) ??
                                'An error occurred',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinkStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLinks(BuildContext context) async {
    final linkChecker = context.read<LinkCheckerProvider>();

    try {
      await linkChecker.checkSiteLinks(site);
      onCheckComplete();
    } catch (e) {
      onCheckError(e.toString());
    }
  }
}
