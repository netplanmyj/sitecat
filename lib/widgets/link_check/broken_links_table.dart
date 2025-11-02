import 'package:flutter/material.dart';
import '../../models/broken_link.dart';

/// Widget to display broken links in a data table
class BrokenLinksTable extends StatelessWidget {
  final List<BrokenLink> brokenLinks;

  const BrokenLinksTable({super.key, required this.brokenLinks});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('URL')),
          DataColumn(label: Text('Found On')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Error')),
        ],
        rows: brokenLinks.map((link) {
          return DataRow(
            cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(link.url, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(link.foundOn, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                Text(
                  link.statusCode.toString(),
                  style: TextStyle(
                    color: _getStatusColor(link.statusCode),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    link.error ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.orange;
    if (statusCode >= 400 && statusCode < 500) return Colors.red;
    if (statusCode >= 500) return Colors.purple;
    return Colors.grey;
  }
}
