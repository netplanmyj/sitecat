import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/site_provider.dart';
import '../../models/site.dart';
import 'site_form_fields.dart';
import 'excluded_paths_editor.dart';

class SiteFormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController sitemapUrlController;
  final TextEditingController newPathController;
  final List<String> excludedPaths;
  final bool isEdit;
  final Site? editingSite;
  final VoidCallback onAddPath;
  final Function(int) onRemovePath;

  const SiteFormBody({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.urlController,
    required this.sitemapUrlController,
    required this.newPathController,
    required this.excludedPaths,
    required this.isEdit,
    this.editingSite,
    required this.onAddPath,
    required this.onRemovePath,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteProvider>(
      builder: (context, siteProvider, child) {
        return Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(context),
              const SizedBox(height: 16),
              _buildSiteNameField(siteProvider),
              const SizedBox(height: 16),
              _buildSiteUrlField(siteProvider),
              const SizedBox(height: 16),
              _buildSitemapUrlField(),
              const SizedBox(height: 16),
              _buildExcludedPathsSection(),
              const SizedBox(height: 24),
              if (siteProvider.error != null)
                _buildErrorMessage(siteProvider.error!),
              _buildHelpCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return SiteFormFields.buildHeaderCard(isEdit: isEdit, context: context);
  }

  Widget _buildSiteNameField(SiteProvider siteProvider) {
    return SiteFormFields.buildSiteNameField(
      controller: nameController,
      siteProvider: siteProvider,
    );
  }

  Widget _buildSiteUrlField(SiteProvider siteProvider) {
    return SiteFormFields.buildSiteUrlField(
      controller: urlController,
      siteProvider: siteProvider,
      excludeSiteId: editingSite?.id,
    );
  }

  Widget _buildSitemapUrlField() {
    return SiteFormFields.buildSitemapUrlField(
      controller: sitemapUrlController,
    );
  }

  Widget _buildExcludedPathsSection() {
    return ExcludedPathsEditor(
      pathController: newPathController,
      excludedPaths: excludedPaths,
      onAddPath: onAddPath,
      onRemovePath: onRemovePath,
    );
  }

  Widget _buildErrorMessage(String error) {
    return SiteFormFields.buildErrorMessage(error: error);
  }

  Widget _buildHelpCard() {
    return SiteFormFields.buildHelpCard();
  }
}
