import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site.dart';
import '../providers/monitoring_provider.dart';
import '../widgets/site_info_card.dart';
import '../widgets/site_stats_card.dart';
import '../widgets/link_check_section.dart';
import '../widgets/monitoring_result_card.dart';
import 'broken_links_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;

  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to monitoring results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().listenToSiteResults(widget.site.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.site.name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteInfoCard(site: widget.site),
              const SizedBox(height: 16),
              _buildCheckButton(),
              const SizedBox(height: 16),
              LinkCheckSection(
                site: widget.site,
                onCheckComplete: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link check completed'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onCheckError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                onViewBrokenLinks: (site, brokenLinks, result) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BrokenLinksScreen(
                        site: site,
                        brokenLinks: brokenLinks,
                        result: result,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              MonitoringResultCard(siteId: widget.site.id),
              const SizedBox(height: 16),
              SiteStatsCard(siteId: widget.site.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return Consumer<MonitoringProvider>(
      builder: (context, provider, child) {
        final isChecking = provider.isChecking(widget.site.id);
        final canCheck = provider.canCheckSite(widget.site.id);
        final timeUntilNext = provider.getTimeUntilNextCheck(widget.site.id);

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isChecking || !canCheck)
                    ? null
                    : () => _checkSite(),
                icon: isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(isChecking ? 'Checking...' : 'Check Site'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (timeUntilNext != null) ...[
              const SizedBox(height: 8),
              Text(
                'Next check available in: ${timeUntilNext.inMinutes}:${(timeUntilNext.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _checkSite() async {
    final provider = context.read<MonitoringProvider>();
    await provider.checkSite(widget.site);

    if (!mounted) return;

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
