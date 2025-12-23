import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/models/site.dart';
import 'package:sitecat/services/link_checker_service.dart';
import 'package:sitecat/providers/link_checker_cache.dart';
import 'package:sitecat/providers/link_checker_progress.dart';
import 'package:sitecat/providers/link_checker_provider.dart';
import 'package:sitecat/services/cooldown_service.dart';
import 'package:sitecat/services/site_service.dart';
import 'package:sitecat/utils/navigation_guard.dart';

class _FakeLinkCheckerClient implements LinkCheckerClient {
  @override
  Future<void> deleteLinkCheckResult(String resultId) {
    throw UnimplementedError();
  }

  @override
  Future<List<LinkCheckResult>> getAllCheckResults({int limit = 50}) {
    throw UnimplementedError();
  }

  @override
  Future<List<BrokenLink>> getBrokenLinks(String resultId) {
    throw UnimplementedError();
  }

  @override
  Future<List<LinkCheckResult>> getCheckResults(
    String siteId, {
    int limit = 10,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LinkCheckResult> checkSiteLinks(
    Site site, {
    bool checkExternalLinks = true,
    bool continueFromLastScan = false,
    int? precalculatedPageCount,
    List<Uri>? cachedSitemapUrls,
    void Function(int checked, int total)? onProgress,
    void Function(int checked, int total)? onExternalLinksProgress,
    void Function(int? statusCode)? onSitemapStatusUpdate,
    bool Function()? shouldCancel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LinkCheckResult?> getLatestCheckResult(String siteId) {
    throw UnimplementedError();
  }

  @override
  Future<int?> loadSitemapPageCount(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Uri>?> loadSitemapUrls(
    Site site, {
    void Function(int? statusCode)? onSitemapStatusUpdate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveInterruptedResult(LinkCheckResult result) async {}

  @override
  void setHistoryLimit(bool isPremium) {}

  @override
  void setPageLimit(bool isPremium) {}
}

class _FakeSiteUpdater implements SiteUpdater {
  @override
  Future<void> updateSite(Site site) async {}
}

class _StubProvider extends LinkCheckerProvider {
  bool scanning = false;
  bool saved = false;

  _StubProvider()
    : super(
        linkCheckerService: _FakeLinkCheckerClient(),
        siteService: _FakeSiteUpdater(),
        cooldownService: DefaultCooldownService(),
        cache: LinkCheckerCache(),
        progress: LinkCheckerProgress(),
      );

  @override
  bool isChecking(String siteId) => scanning;

  @override
  Future<void> saveProgressAndReset(String siteId) async {
    saved = true;
    scanning = false;
  }
}

Widget _wrapWithApp(Widget child, LinkCheckerProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<LinkCheckerProvider>.value(
      value: provider,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('returns true immediately when not scanning', (tester) async {
    final stub = _StubProvider()..scanning = false;
    await tester.pumpWidget(_wrapWithApp(const SizedBox(), stub));
    final context = tester.element(find.byType(Scaffold));

    final ok = await confirmAndSaveIfScanning(context, 'site_1');
    expect(ok, isTrue);
    expect(stub.saved, isFalse);
  });

  testWidgets('shows dialog and saves when user confirms', (tester) async {
    final stub = _StubProvider()..scanning = true;
    await tester.pumpWidget(_wrapWithApp(const SizedBox(), stub));
    final context = tester.element(find.byType(Scaffold));

    // Start the guard
    final future = confirmAndSaveIfScanning(context, 'site_1');
    await tester.pumpAndSettle();

    // Confirm dialog should be visible
    expect(find.text('End scan?'), findsOneWidget);

    // Tap OK (Save and End)
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save and End'));
    await tester.pumpAndSettle();

    final ok = await future;
    expect(ok, isTrue);
    expect(stub.saved, isTrue);
    expect(stub.scanning, isFalse);
  });

  testWidgets('returns false when user cancels', (tester) async {
    final stub = _StubProvider()..scanning = true;
    await tester.pumpWidget(_wrapWithApp(const SizedBox(), stub));
    final context = tester.element(find.byType(Scaffold));

    final future = confirmAndSaveIfScanning(context, 'site_1');
    await tester.pumpAndSettle();
    expect(find.text('End scan?'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    final ok = await future;
    expect(ok, isFalse);
    expect(stub.saved, isFalse);
    expect(stub.scanning, isTrue); // unchanged
  });
}
