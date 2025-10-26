import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/site_provider.dart';
import '../models/site.dart';

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
  final _intervalController = TextEditingController();

  bool _monitoringEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      // Populate form with existing site data
      _nameController.text = widget.site!.name;
      _urlController.text = widget.site!.url;
      _intervalController.text = widget.site!.checkInterval.toString();
      _monitoringEnabled = widget.site!.monitoringEnabled;
    } else {
      // Default values for new site
      _intervalController.text = '60'; // Default 60 minutes
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _intervalController.dispose();
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

                // Monitoring Settings Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monitoring Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Monitoring enabled switch
                        SwitchListTile(
                          title: const Text('Enable Monitoring'),
                          subtitle: Text(
                            _monitoringEnabled
                                ? 'Site monitoring is active'
                                : 'Site monitoring is paused',
                          ),
                          value: _monitoringEnabled,
                          onChanged: (value) {
                            setState(() {
                              _monitoringEnabled = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),

                        const SizedBox(height: 16),

                        // Check interval field
                        const Text(
                          'Check Interval (minutes)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _intervalController,
                          decoration: const InputDecoration(
                            hintText: '60',
                            suffixText: 'minutes',
                            prefixIcon: Icon(Icons.schedule),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              siteProvider.validateCheckInterval(value),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Recommended: 60 minutes or more to avoid rate limiting',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
                          child: Text(
                            widget.isEdit ? 'Update Site' : 'Add Site',
                          ),
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
                          '• Set appropriate check intervals to avoid overloading servers\n'
                          '• You can pause monitoring anytime without losing your settings',
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
          monitoringEnabled: _monitoringEnabled,
          checkInterval: int.parse(_intervalController.text),
        );
        success = await siteProvider.updateSite(updatedSite);
      } else {
        // Create new site
        success = await siteProvider.createSite(
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          monitoringEnabled: _monitoringEnabled,
          checkInterval: int.parse(_intervalController.text),
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
}
