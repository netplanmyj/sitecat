import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:sitecat/widgets/broken_links/broken_links_list.dart';

void main() {
  group('BrokenLinksList URL Decoding', () {
    testWidgets('decodes URL-encoded Japanese characters correctly', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test1',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          url: 'https://example.com/tags/%E9%96%8B%E7%99%BA/',
          foundOn: 'https://example.com/index.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display decoded Japanese text "開発"
      expect(find.textContaining('開発'), findsOneWidget);
      // Should not display encoded text
      expect(find.textContaining('%E9%96%8B%E7%99%BA'), findsNothing);
    });

    testWidgets('handles already-decoded URLs correctly', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test2',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          url: 'https://example.com/page/about',
          foundOn: 'https://example.com/index.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display unchanged URL
      expect(find.textContaining('/page/about'), findsOneWidget);
    });

    testWidgets('decodes URLs with special characters', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test3',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          url: 'https://example.com/search?q=%E6%A4%9C%E7%B4%A2',
          foundOn: 'https://example.com/index.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display decoded query parameter "検索"
      expect(find.textContaining('検索'), findsOneWidget);
    });

    testWidgets('handles invalid encoded sequences gracefully', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test4',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          // Invalid percent encoding (incomplete sequence)
          url: 'https://example.com/invalid/%E9%96',
          foundOn: 'https://example.com/index.html',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display something (either decoded or original)
      // The important thing is it doesn't crash
      expect(find.byType(BrokenLinksList), findsOneWidget);
    });

    testWidgets('decodes "Found On" URLs correctly', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test5',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          url: 'https://example.com/broken',
          foundOn: 'https://example.com/tags/%E9%96%8B%E7%99%BA/',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display decoded "Found on" text
      expect(find.textContaining('開発'), findsOneWidget);
    });

    testWidgets('displays empty state when no broken links', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: [])),
        ),
      );

      expect(find.text('No broken links in this category'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('fixes double-encoded Japanese characters (mojibake)', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test7',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          // Double-encoded "開発" appears as éçº in decoded form
          url:
              'https://netplan.co.jp/posts/tags/%C3%A9%C2%96%C2%8B%C3%A7%C2%99%C2%BA/',
          foundOn: 'https://netplan.co.jp/posts/',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.internal,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should display correctly decoded Japanese text "開発"
      expect(find.textContaining('開発'), findsOneWidget);
      // Should not display the specific mojibake pattern 'éçº'
      expect(find.textContaining('éçº'), findsNothing);
    });

    testWidgets('does not affect European language URLs', (
      WidgetTester tester,
    ) async {
      final brokenLinks = [
        BrokenLink(
          id: 'test8',
          siteId: 'site1',
          userId: 'user1',
          timestamp: DateTime.now(),
          // French URL with é should not be modified
          url: 'https://example.fr/café',
          foundOn: 'https://example.fr/',
          statusCode: 404,
          error: 'Not Found',
          linkType: LinkType.external,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BrokenLinksList(links: brokenLinks)),
        ),
      );

      // Should keep é in café (not Japanese mojibake)
      expect(find.textContaining('café'), findsOneWidget);
    });
  });
}
