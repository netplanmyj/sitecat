import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../providers/site_provider.dart';
import '../providers/subscription_provider.dart';

/// Screen for editing excluded paths (Premium feature)
class ExcludedPathsScreen extends StatefulWidget {
  final Site site;

  const ExcludedPathsScreen({super.key, required this.site});

  @override
  State<ExcludedPathsScreen> createState() => _ExcludedPathsScreenState();
}

class _ExcludedPathsScreenState extends State<ExcludedPathsScreen> {
  late List<String> _paths;
  final TextEditingController _newPathController = TextEditingController();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.site.excludedPaths);
  }

  @override
  void dispose() {
    _newPathController.dispose();
    super.dispose();
  }

  void _addPath() {
    final path = _newPathController.text.trim();
    if (path.isEmpty) return;

    // Validate path format: must end with / or use wildcard pattern like */temp/
    // Examples: tags/, */temp/, categories/
    // Invalid: admin (missing /), admin/* (should be admin/ or */admin/)
    if (!path.endsWith('/') && !path.contains('*/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Path should end with / or use wildcard pattern like */temp/',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paths.contains(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Path already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _paths.add(path);
      _newPathController.clear();
      _hasChanges = true;
    });
  }

  void _removePath(int index) {
    setState(() {
      _paths.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _savePaths() async {
    final siteProvider = context.read<SiteProvider>();
    final updatedSite = widget.site.copyWith(excludedPaths: _paths);

    final success = await siteProvider.updateSite(updatedSite);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excluded paths saved'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(siteProvider.error ?? 'Failed to save'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final isPremium = subscriptionProvider.hasLifetimeAccess;

    // TODO(#210): Security - Move premium gating to backend
    // Currently, access control is client-side only which can be bypassed.
    // Future implementation should reject updates for excluded paths
    // on the backend when user lacks premium entitlement.
    if (!isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Excluded Paths'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Premium Feature',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to Premium to configure excluded paths',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to purchase screen would go here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('View Premium'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excluded Paths'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _savePaths,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Exclude paths from scanning',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Examples:\n'
                  '• tags/ - Excludes all pages under tags/\n'
                  '• admin/* - Excludes admin section\n'
                  '• */temp/ - Excludes temp folders',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),

          // Add path section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPathController,
                    decoration: InputDecoration(
                      labelText: 'New path pattern',
                      hintText: 'e.g., tags/ or admin/*',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addPath(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addPath,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Paths list
          Expanded(
            child: _paths.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No excluded paths',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add paths to exclude from scanning',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _paths.length,
                    itemBuilder: (context, index) {
                      final path = _paths[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.block,
                            color: Colors.orange.shade700,
                          ),
                          title: Text(
                            path,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removePath(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
