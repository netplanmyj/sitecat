import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../utils/date_formatter.dart';

class BrokenLinksList extends StatelessWidget {
  final List<BrokenLink> links;

  const BrokenLinksList({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'No broken links in this category',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(link.statusCode),
              child: Text(
                link.statusCode.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              link.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              'Found on: ${link.foundOn}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('URL', link.url),
                    const SizedBox(height: 8),
                    _buildDetailRow('Found On', link.foundOn),
                    const SizedBox(height: 8),
                    _buildDetailRow('Status Code', link.statusCode.toString()),
                    if (link.error != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Error', link.error!),
                    ],
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Checked At',
                      DateFormatter.formatFullDateTime(link.timestamp),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Type',
                      link.linkType == LinkType.internal
                          ? 'Internal'
                          : 'External',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.orange;
    } else if (statusCode >= 400 && statusCode < 500) {
      return Colors.red;
    } else if (statusCode >= 500) {
      return Colors.purple;
    }
    return Colors.grey;
  }
}
