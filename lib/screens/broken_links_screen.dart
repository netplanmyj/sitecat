import 'package:flutter/material.dart';
import '../models/broken_link.dart';
import '../models/site.dart';

/// Screen to display detailed broken links results
class BrokenLinksScreen extends StatelessWidget {
  final Site site;
  final List<BrokenLink> brokenLinks;
  final LinkCheckResult? result;

  const BrokenLinksScreen({
    super.key,
    required this.site,
    required this.brokenLinks,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    final internalLinks = brokenLinks
        .where((link) => link.linkType == LinkType.internal)
        .toList();
    final externalLinks = brokenLinks
        .where((link) => link.linkType == LinkType.external)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('壊れたリンク'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Summary card
          if (result != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          '総リンク数',
                          result!.totalLinks.toString(),
                          Icons.link,
                          Colors.blue,
                        ),
                        _buildSummaryItem(
                          '内部リンク',
                          result!.internalLinks.toString(),
                          Icons.home,
                          Colors.green,
                        ),
                        _buildSummaryItem(
                          '外部リンク',
                          result!.externalLinks.toString(),
                          Icons.public,
                          Colors.orange,
                        ),
                        _buildSummaryItem(
                          '壊れたリンク',
                          result!.brokenLinks.toString(),
                          Icons.link_off,
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Tabs for internal/external links
          Expanded(
            child: brokenLinks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '壊れたリンクはありません',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(text: '内部リンク (${internalLinks.length})'),
                            Tab(text: '外部リンク (${externalLinks.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildLinksList(internalLinks),
                              _buildLinksList(externalLinks),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLinksList(List<BrokenLink> links) {
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'このカテゴリに壊れたリンクはありません',
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
              '発見場所: ${link.foundOn}',
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
                    _buildDetailRow('発見場所', link.foundOn),
                    const SizedBox(height: 8),
                    _buildDetailRow('ステータスコード', link.statusCode.toString()),
                    if (link.error != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('エラー', link.error!),
                    ],
                    const SizedBox(height: 8),
                    _buildDetailRow('チェック時刻', _formatDateTime(link.timestamp)),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'タイプ',
                      link.linkType == LinkType.internal ? '内部' : '外部',
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

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
