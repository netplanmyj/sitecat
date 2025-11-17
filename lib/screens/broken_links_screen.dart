import 'package:flutter/material.dart';
import '../models/broken_link.dart';
import '../models/site.dart';
import '../widgets/broken_links/broken_links_summary_card.dart';
import '../widgets/broken_links/broken_links_list.dart';

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
        title: const Text('Scan Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Summary card
          if (result != null)
            BrokenLinksSummaryCard(site: site, result: result!),

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
                          'No broken links found',
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
                            Tab(text: 'Internal (${internalLinks.length})'),
                            Tab(text: 'External (${externalLinks.length})'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              BrokenLinksList(links: internalLinks),
                              BrokenLinksList(links: externalLinks),
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
}
