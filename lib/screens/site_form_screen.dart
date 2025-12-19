import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/site_provider.dart';
import '../providers/link_checker_provider.dart';
import '../models/site.dart';
import '../constants/app_constants.dart';
import '../widgets/site_form/site_form_body.dart';
import '../widgets/site_form/action_buttons.dart';
import '../widgets/site_form/site_limit_card.dart';
import '../widgets/site_form/url_change_warning_dialog.dart';

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
            return SiteLimitCard(
              siteCount: siteProvider.siteCount,
              siteLimit: AppConstants.freePlanSiteLimit,
              onBackPressed: () => Navigator.of(context).pop(),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SiteFormBody(
                  formKey: _formKey,
                  nameController: _nameController,
                  urlController: _urlController,
                  sitemapUrlController: _sitemapUrlController,
                  newPathController: _newPathController,
                  excludedPaths: _excludedPaths,
                  isEdit: widget.isEdit,
                  editingSite: widget.site,
                  onAddPath: _addExcludedPath,
                  onRemovePath: _removeExcludedPath,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: ActionButtons(
                  isLoading: _isLoading,
                  isEdit: widget.isEdit,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _saveSite,
                ),
              ),
            ],
          );
        },
      ),
    );
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

        // Clear pre-calculated page count cache in case excluded paths changed
        if (success && mounted) {
          final linkCheckerProvider = Provider.of<LinkCheckerProvider>(
            context,
            listen: false,
          );
          linkCheckerProvider.clearPrecalculatedPageCount(updatedSite.id);
        }
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
      } else if (!success && mounted) {
        final siteProvider = Provider.of<SiteProvider>(context, listen: false);
        final message = siteProvider.error ?? 'Failed to save site';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
      builder: (context) => UrlChangeWarningDialog(
        oldUrl: widget.site!.url,
        newUrl: _urlController.text.trim(),
      ),
    );
    return result ?? false;
  }
}
