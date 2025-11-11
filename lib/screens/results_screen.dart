import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/link_checker_provider.dart';
import '../widgets/results/all_results_tab.dart';
import '../widgets/results/by_site_tab.dart';

/// Results screen with tabs for [All Results] and [By Site]
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LinkCheckerProvider>().loadAllCheckHistory(limit: 50);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Results', icon: Icon(Icons.list)),
            Tab(text: 'By Site', icon: Icon(Icons.web)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [AllResultsTab(), BySiteTab()],
      ),
    );
  }
}
