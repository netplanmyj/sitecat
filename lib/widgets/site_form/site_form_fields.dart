import 'package:flutter/material.dart';
import '../../providers/site_provider.dart';

/// Form fields for site registration/editing
class SiteFormFields {
  // Private constructor to prevent instantiation
  SiteFormFields._();

  /// Build site name input field
  static Widget buildSiteNameField({
    required TextEditingController controller,
    required SiteProvider siteProvider,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter a friendly name for your site',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => siteProvider.validateSiteName(value),
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
      ),
    );
  }

  /// Build site URL input field
  static Widget buildSiteUrlField({
    required TextEditingController controller,
    required SiteProvider siteProvider,
    String? excludeSiteId,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Website URL',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              validator: (value) => siteProvider.validateSiteUrl(
                value,
                excludeSiteId: excludeSiteId,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
      ),
    );
  }

  /// Build sitemap URL input field
  static Widget buildSitemapUrlField({
    required TextEditingController controller,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sitemap URL (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'sitemap.xml or https://example.com/sitemap.xml',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
                helperText: 'Full URL or relative path (e.g., sitemap.xml)',
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
    );
  }

  /// Build header card
  static Widget buildHeaderCard({
    required bool isEdit,
    required BuildContext context,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.add,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Update Site Information' : 'Add New Site',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEdit
                  ? 'Update the details for your site monitoring'
                  : 'Enter the details for your new site monitoring',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Build help card with tips
  static Widget buildHelpCard() {
    return Card(
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
              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error message widget
  static Widget buildErrorMessage({required String error}) {
    return Container(
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
            child: Text(error, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}
