import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/services/link_checker/result_builder.dart';
import 'package:sitecat/models/broken_link.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

void main() {
  group('ResultBuilder', () {
    late ResultBuilder resultBuilder;
    const testSiteId = 'test-site-id';
    const testUserId = 'test-user-id';

    setUp(() {
      // Create a minimal ResultBuilder instance for testing pure logic methods
      // We don't need real Firestore/Logger for mergeBrokenLinks tests
      resultBuilder = ResultBuilder(
        firestore: FakeFirebaseFirestore(),
        logger: Logger(printer: PrettyPrinter()),
        historyLimit: 10,
      );
    });

    group('mergeBrokenLinks', () {
      test(
        'should return only new broken links when continueFromLastScan is false',
        () {
          // Arrange
          final newLinks = [
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '1',
              url: 'https://example.com/new1',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 404,
              timestamp: DateTime.now(),
            ),
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '2',
              url: 'https://example.com/new2',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 500,
              timestamp: DateTime.now(),
            ),
          ];

          final previousLinks = [
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '3',
              url: 'https://example.com/old1',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 404,
              timestamp: DateTime.now(),
            ),
          ];

          // Act
          final result = resultBuilder.mergeBrokenLinks(
            newBrokenLinks: newLinks,
            previousBrokenLinks: previousLinks,
            continueFromLastScan: false,
          );

          // Assert
          expect(result, hasLength(2));
          expect(result, equals(newLinks));
          expect(result, isNot(contains(previousLinks[0])));
        },
      );

      test(
        'should merge new and previous broken links when continueFromLastScan is true',
        () {
          // Arrange
          final newLinks = [
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '1',
              url: 'https://example.com/new1',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 404,
              timestamp: DateTime.now(),
            ),
          ];

          final previousLinks = [
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '2',
              url: 'https://example.com/old1',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 404,
              timestamp: DateTime.now(),
            ),
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '3',
              url: 'https://example.com/old2',
              foundOn: 'https://example.com',
              linkType: LinkType.external,
              statusCode: 500,
              timestamp: DateTime.now(),
            ),
          ];

          // Act
          final result = resultBuilder.mergeBrokenLinks(
            newBrokenLinks: newLinks,
            previousBrokenLinks: previousLinks,
            continueFromLastScan: true,
          );

          // Assert
          expect(result, hasLength(3));
          expect(result[0], equals(previousLinks[0]));
          expect(result[1], equals(previousLinks[1]));
          expect(result[2], equals(newLinks[0]));
        },
      );

      test(
        'should return only new links when continueFromLastScan is true but previousBrokenLinks is empty',
        () {
          // Arrange
          final newLinks = [
            BrokenLink(
              siteId: testSiteId,
              userId: testUserId,
              id: '1',
              url: 'https://example.com/new1',
              foundOn: 'https://example.com',
              linkType: LinkType.internal,
              statusCode: 404,
              timestamp: DateTime.now(),
            ),
          ];

          final previousLinks = <BrokenLink>[];

          // Act
          final result = resultBuilder.mergeBrokenLinks(
            newBrokenLinks: newLinks,
            previousBrokenLinks: previousLinks,
            continueFromLastScan: true,
          );

          // Assert
          expect(result, hasLength(1));
          expect(result, equals(newLinks));
        },
      );

      test(
        'should return empty list when both new and previous lists are empty',
        () {
          // Arrange
          final newLinks = <BrokenLink>[];
          final previousLinks = <BrokenLink>[];

          // Act
          final result = resultBuilder.mergeBrokenLinks(
            newBrokenLinks: newLinks,
            previousBrokenLinks: previousLinks,
            continueFromLastScan: false,
          );

          // Assert
          expect(result, isEmpty);
        },
      );

      test('should handle empty new links with continueFromLastScan true', () {
        // Arrange
        final newLinks = <BrokenLink>[];
        final previousLinks = [
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: '1',
            url: 'https://example.com/old1',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 404,
            timestamp: DateTime.now(),
          ),
        ];

        // Act
        final result = resultBuilder.mergeBrokenLinks(
          newBrokenLinks: newLinks,
          previousBrokenLinks: previousLinks,
          continueFromLastScan: true,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result, equals(previousLinks));
      });

      test('should preserve order: previous links first, then new links', () {
        // Arrange
        final newLinks = [
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: 'new1',
            url: 'https://example.com/new1',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 404,
            timestamp: DateTime.now(),
          ),
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: 'new2',
            url: 'https://example.com/new2',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 500,
            timestamp: DateTime.now(),
          ),
        ];

        final previousLinks = [
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: 'old1',
            url: 'https://example.com/old1',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 404,
            timestamp: DateTime.now(),
          ),
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: 'old2',
            url: 'https://example.com/old2',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 500,
            timestamp: DateTime.now(),
          ),
        ];

        // Act
        final result = resultBuilder.mergeBrokenLinks(
          newBrokenLinks: newLinks,
          previousBrokenLinks: previousLinks,
          continueFromLastScan: true,
        );

        // Assert
        expect(result, hasLength(4));
        expect(result[0].id, 'old1');
        expect(result[1].id, 'old2');
        expect(result[2].id, 'new1');
        expect(result[3].id, 'new2');
      });

      test('should not modify original lists', () {
        // Arrange
        final newLinks = [
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: '1',
            url: 'https://example.com/new1',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 404,
            timestamp: DateTime.now(),
          ),
        ];

        final previousLinks = [
          BrokenLink(
            siteId: testSiteId,
            userId: testUserId,
            id: '2',
            url: 'https://example.com/old1',
            foundOn: 'https://example.com',
            linkType: LinkType.internal,
            statusCode: 404,
            timestamp: DateTime.now(),
          ),
        ];

        final originalNewLinksLength = newLinks.length;
        final originalPreviousLinksLength = previousLinks.length;

        // Act
        final result = resultBuilder.mergeBrokenLinks(
          newBrokenLinks: newLinks,
          previousBrokenLinks: previousLinks,
          continueFromLastScan: true,
        );

        // Assert
        expect(result, hasLength(2));
        expect(newLinks, hasLength(originalNewLinksLength)); // Unchanged
        expect(
          previousLinks,
          hasLength(originalPreviousLinksLength),
        ); // Unchanged
      });
    });
  });
}

/// Minimal fake Firestore instance for testing.
/// This class is only intended for tests of pure logic methods that do not require any Firestore functionality.
/// If Firestore methods are needed, use a more complete mock or fake.
class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}
