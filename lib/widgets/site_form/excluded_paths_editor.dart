import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/subscription_provider.dart';

/// Widget for editing excluded paths (Premium feature)
class ExcludedPathsEditor extends StatelessWidget {
  final TextEditingController pathController;
  final List<String> excludedPaths;
  final VoidCallback onAddPath;
  final void Function(int) onRemovePath;

  const ExcludedPathsEditor({
    super.key,
    required this.pathController,
    required this.excludedPaths,
    required this.onAddPath,
    required this.onRemovePath,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final isPremium = subscriptionProvider.hasLifetimeAccess;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isPremium),
                const SizedBox(height: 8),
                if (!isPremium)
                  _buildPremiumPrompt()
                else ...[
                  _buildDescription(),
                  const SizedBox(height: 12),
                  _buildPatternExamples(),
                  const SizedBox(height: 12),
                  _buildPathInput(),
                  if (excludedPaths.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPathList(),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isPremium) {
    return Row(
      children: [
        const Text(
          'Excluded Paths',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        if (!isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Text(
              'Premium',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumPrompt() {
    return Text(
      'Upgrade to Premium to exclude specific paths from scanning',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }

  Widget _buildDescription() {
    return Text(
      'Exclude specific paths from Site Scan',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }

  Widget _buildPatternExamples() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Path Pattern Examples:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• blog/tags/ - Excludes paths starting with /blog/tags/\n'
            '• */admin/ - Excludes paths with "admin" as a path segment\n'
            '• */temp/ - Excludes paths with "temp" as a path segment',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: pathController,
            decoration: const InputDecoration(
              hintText: 'e.g., blog/tags/ or */admin/',
              prefixIcon: Icon(Icons.block),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
            onSubmitted: (_) => onAddPath(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onAddPath,
          icon: const Icon(Icons.add_circle),
          color: Colors.green,
          iconSize: 32,
        ),
      ],
    );
  }

  Widget _buildPathList() {
    return Column(
      children: List.generate(
        excludedPaths.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.block,
                size: 20,
                color: Colors.orange.shade700,
              ),
              title: Text(
                excludedPaths[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.red,
                onPressed: () => onRemovePath(index),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
