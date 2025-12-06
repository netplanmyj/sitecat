import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/site_provider.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../widgets/site_form/excluded_paths_editor.dart';
import '../widgets/site_form/site_form_fields.dart';

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
  final _newPathController = TextEditingController();

  late List<String> _excludedPaths;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      // Populate form with existing site data
      _nameController.text = widget.site!.name;
      _urlController.text = widget.site!.url;
      _sitemapUrlController.text = widget.site!.sitemapUrl ?? '';
      _excludedPaths = List.from(widget.site!.excludedPaths);
    } else {
      _excludedPaths = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _sitemapUrlController.dispose();
    _newPathController.dispose();
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
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildSiteNameField(siteProvider),
                const SizedBox(height: 16),
                _buildSiteUrlField(siteProvider),
                const SizedBox(height: 16),
                _buildSitemapUrlField(),
                const SizedBox(height: 16),
                _buildExcludedPathsSection(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 16),
                if (siteProvider.error != null)
                  _buildErrorMessage(siteProvider.error!),
                _buildHelpCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return SiteFormFields.buildHeaderCard(
      isEdit: widget.isEdit,
      context: context,
    );
  }

  Widget _buildSiteNameField(SiteProvider siteProvider) {
    return SiteFormFields.buildSiteNameField(
      controller: _nameController,
      siteProvider: siteProvider,
    );
  }

  Widget _buildSiteUrlField(SiteProvider siteProvider) {
    return SiteFormFields.buildSiteUrlField(
      controller: _urlController,
      siteProvider: siteProvider,
      excludeSiteId: widget.site?.id,
    );
  }

  Widget _buildSitemapUrlField() {
    return SiteFormFields.buildSitemapUrlField(
      controller: _sitemapUrlController,
    );
  }

  Widget _buildExcludedPathsSection() {
    return ExcludedPathsEditor(
      pathController: _newPathController,
      excludedPaths: _excludedPaths,
      onAddPath: _addExcludedPath,
      onRemovePath: _removeExcludedPath,
    );
  }

  Widget _buildActionButtons() {
    if (_isLoading) {
      return const Card(
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
      );
    }

    return Row(
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
    );
  }

  Widget _buildErrorMessage(String error) {
    return SiteFormFields.buildErrorMessage(error: error);
  }

  Widget _buildHelpCard() {
    return SiteFormFields.buildHelpCard();
  }

  void _addExcludedPath() {
    final path = _newPathController.text.trim();
    if (path.isEmpty) return;

    // Validate path format: must end with /
    if (!path.endsWith('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Path must end with /'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If it contains *, it must be a valid wildcard pattern (*/segment/)
    if (path.contains('*') && !path.startsWith('*/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wildcard pattern must start with */ (e.g., */admin/)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_excludedPaths.contains(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Path already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _excludedPaths.add(path);
      _newPathController.clear();
    });
  }

  void _removeExcludedPath(int index) {
    setState(() {
      _excludedPaths.removeAt(index);
    });
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
          excludedPaths: _excludedPaths,
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
          excludedPaths: _excludedPaths,
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
