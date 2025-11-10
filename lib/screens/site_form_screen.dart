import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/site_provider.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';

class SiteFormScreen extends StatefulWidget {
  final Site? site; // null for create, Site for edit

  const SiteFormScreen({super.key, this.site});

  bool get isEdit => site != null;

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _sitemapUrlController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      // Populate form with existing site data
      _nameController.text = widget.site!.name;
      _urlController.text = widget.site!.url;
      _sitemapUrlController.text = widget.site!.sitemapUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _sitemapUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Site' : 'Add Site'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSite,
            child: Text(
              widget.isEdit ? 'Update' : 'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<SiteProvider>(
        builder: (context, siteProvider, child) {
          // Check site limit for new sites
          if (!widget.isEdit && !siteProvider.canAddSite) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppConstants.siteLimitReachedMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Current sites: ${siteProvider.siteCount} / ${AppConstants.freePlanSiteLimit}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Sites'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.isEdit ? Icons.edit : Icons.add,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isEdit
                                  ? 'Update Site Information'
                                  : 'Add New Site',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isEdit
                              ? 'Update the details for your site monitoring'
                              : 'Enter the details for your new site monitoring',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Site Name Field
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Site Name',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter a friendly name for your site',
                            prefixIcon: Icon(Icons.label_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              siteProvider.validateSiteName(value),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Site URL Field
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Website URL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: 'https://example.com',
                            prefixIcon: Icon(Icons.link),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => siteProvider.validateSiteUrl(
                            value,
                            excludeSiteId: widget.site?.id,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sitemap URL Field
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sitemap URL (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sitemapUrlController,
                          decoration: const InputDecoration(
                            hintText:
                                'sitemap.xml or https://example.com/sitemap.xml',
                            prefixIcon: Icon(Icons.map_outlined),
                            border: OutlineInputBorder(),
                            helperText:
                                'Full URL or relative path (e.g., sitemap.xml)',
                            helperMaxLines: 2,
                          ),
                          validator: (value) {
                            // Optional field - only validate if not empty
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }

                            // Allow relative paths (e.g., "sitemap.xml" or "/sitemap.xml")
                            if (!value.startsWith('http://') &&
                                !value.startsWith('https://')) {
                              return null; // Relative path is valid
                            }

                            // For full URLs, validate scheme
                            final uri = Uri.tryParse(value);
                            if (uri == null ||
                                !uri.hasScheme ||
                                (!uri.scheme.startsWith('http'))) {
                              return 'Please enter a valid URL';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                if (_isLoading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Saving site...'),
                        ],
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSite,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(widget.isEdit ? 'Update' : 'Add Site'),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Error message
                if (siteProvider.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            siteProvider.error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Help card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Tips',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Use HTTPS URLs when possible for better security\n'
                          '• Choose meaningful names to easily identify your sites\n'
                          '• Add sitemap URL to enable comprehensive link checking\n'
                          '• You can manually check site status and links anytime',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if URL changed (for edit mode)
    if (widget.isEdit) {
      final urlChanged = widget.site!.url != _urlController.text.trim();

      // Show warning dialog if URL changed
      if (urlChanged) {
        final confirm = await _showUrlChangeWarningDialog();
        if (!confirm || !mounted) return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    bool success;

    try {
      if (widget.isEdit) {
        // Update existing site
        final updatedSite = widget.site!.copyWith(
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          sitemapUrl: _sitemapUrlController.text.trim().isEmpty
              ? null
              : _sitemapUrlController.text.trim(),
        );
        success = await siteProvider.updateSite(updatedSite);
      } else {
        // Create new site
        success = await siteProvider.createSite(
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          sitemapUrl: _sitemapUrlController.text.trim().isEmpty
              ? null
              : _sitemapUrlController.text.trim(),
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Site updated successfully'
                  : 'Site added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Error is handled by the provider
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showUrlChangeWarningDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            _buildWarningItem('Previous check results will show as mismatched'),
            const SizedBox(height: 8),
            _buildWarningItem('Link check history will be cleared'),
            const SizedBox(height: 8),
            _buildWarningItem('You may need to run a new full scan'),
            const SizedBox(height: 16),
            Text(
              'Old URL: ${widget.site!.url}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New URL: ${_urlController.text.trim()}',
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
      ),
    );
    return result ?? false;
  }

  Widget _buildWarningItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
