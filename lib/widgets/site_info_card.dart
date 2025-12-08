import 'package:flutter/material.dart';
import '../models/monitoring_result.dart';
import '../models/site.dart';
import 'countdown_timer.dart';

/// Widget to display basic site information with optional sitemap status and cooldown
class SiteInfoCard extends StatefulWidget {
  final Site site;
  final MonitoringResult? sitemapStatus;
  final int? cachedSitemapStatusCode;
  final bool isCheckingSitemap;
  final Duration? Function()? getTimeUntilNextCheck;
  final VoidCallback? onRefreshSitemap;

  const SiteInfoCard({
    super.key,
    required this.site,
    this.sitemapStatus,
    this.cachedSitemapStatusCode,
    this.isCheckingSitemap = false,
    this.getTimeUntilNextCheck,
    this.onRefreshSitemap,
  });

  @override
  State<SiteInfoCard> createState() => _SiteInfoCardState();
}

class _SiteInfoCardState extends State<SiteInfoCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('URL', widget.site.url),
            const SizedBox(height: 8),
            if (widget.site.sitemapUrl != null &&
                widget.site.sitemapUrl!.isNotEmpty) ...[
              _buildSitemapRow(context),
              const SizedBox(height: 8),
            ],
            _buildInfoRow('Updated', _formatDate(widget.site.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _buildSitemapRow(BuildContext context) {
    final statusCode =
        widget.cachedSitemapStatusCode ??
        widget.sitemapStatus?.sitemapStatusCode;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (widget.isCheckingSitemap) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              'Sitemap',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.site.sitemapUrl!),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Checking...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (statusCode == null) {
      statusText = 'Not checked';
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.help_outline;
    } else if (statusCode == 200) {
      statusText = 'OK (200)';
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle;
    } else if (statusCode == 404) {
      statusText = 'Not Found (404)';
      statusColor = Colors.red.shade700;
      statusIcon = Icons.cancel;
    } else if (statusCode == 0) {
      statusText = 'Network Error';
      statusColor = Colors.red.shade700;
      statusIcon = Icons.cloud_off;
    } else {
      statusText = 'Status: $statusCode';
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.error_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 100,
          child: Text(
            'Sitemap',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.site.sitemapUrl!),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.sitemapStatus != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${_formatDate(widget.sitemapStatus!.timestamp)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  if (widget.onRefreshSitemap != null) ...[
                    const Spacer(),
                    Builder(
                      builder: (context) {
                        final remaining = widget.getTimeUntilNextCheck?.call();
                        if (remaining != null && remaining.inSeconds > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              border: Border.all(color: Colors.orange.shade400),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: CountdownTimer(
                              initialDuration: remaining,
                              prefixText: '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                              onComplete: () {
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: widget.onRefreshSitemap,
                      tooltip: 'Refresh sitemap status',
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
