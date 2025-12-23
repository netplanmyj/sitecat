import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/link_checker/scan_orchestrator.dart';
import 'package:sitecat/services/link_checker/http_client.dart';
import 'package:sitecat/services/link_checker/sitemap_parser.dart';
import 'package:http/http.dart' as http;

// No special fakes needed; calculateScanRange doesn't use network.

void main() {
  group('ScanOrchestrator.calculateScanRange', () {
    test('splits into 1-100 then 101-165 and marks completion', () {
      // Arrange: 165 fake pages
      final pages = List<Uri>.generate(
        165,
        (i) => Uri.parse('https://example.com/page/${i + 1}'),
      );

      final raw = http.Client();
      final orchestrator = ScanOrchestrator(
        httpClient: LinkCheckerHttpClient(raw),
        sitemapParser: SitemapParser(raw, maxPageLimit: 1000),
        pageLimit: 1000, // high enough to not limit the test
      );

      // Act + Assert: first batch from index 0 => 100 pages (1..100)
      final first = orchestrator.calculateScanRange(
        allPages: pages,
        startIndex: 0,
      );
      expect(first.pagesToScan.length, 100);
      expect(first.endIndex, 100);
      expect(first.scanCompleted, isFalse);

      // Act + Assert: second batch from index 100 => 65 pages (101..165), completed
      final second = orchestrator.calculateScanRange(
        allPages: pages,
        startIndex: 100,
      );
      expect(second.pagesToScan.length, 65);
      expect(second.endIndex, 165);
      expect(second.scanCompleted, isTrue);
    });
  });
}
