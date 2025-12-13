import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/models/broken_link.dart'
    show BrokenLink, LinkCheckResult, LinkType;
import 'package:sitecat/models/site.dart';

void main() {
  group('Site', () {
    test('toFirestore and fromFirestore are consistent', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.parse('2024-01-01T12:00:00Z');

      final ref = await firestore
          .collection('users')
          .doc('u1')
          .collection('sites')
          .add({
            'userId': 'u1',
            'url': 'https://example.com',
            'name': 'Example',
            'monitoringEnabled': true,
            'checkInterval': 30,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
            'lastChecked': Timestamp.fromDate(now),
            'sitemapUrl': '/sitemap.xml',
            'lastScannedPageIndex': 5,
            'excludedPaths': ['private', 'drafts'],
          });

      final snapshot = await ref.get();
      final site = Site.fromFirestore(snapshot);

      expect(site.id, ref.id);
      expect(site.userId, 'u1');
      expect(site.url, 'https://example.com');
      expect(site.lastScannedPageIndex, 5);
      expect(site.excludedPaths, ['private', 'drafts']);

      final map = site.toFirestore();
      expect(map['url'], 'https://example.com');
      expect(map['excludedPaths'], ['private', 'drafts']);
      expect(map['lastScannedPageIndex'], 5);
    });

    test('copyWith overrides selected fields only', () {
      final now = DateTime.parse('2024-01-01T12:00:00Z');
      final site = Site(
        id: 's1',
        userId: 'u1',
        url: 'https://example.com',
        name: 'Example',
        createdAt: now,
        updatedAt: now,
      );

      final updated = site.copyWith(url: 'https://new.com', name: 'New');

      expect(updated.url, 'https://new.com');
      expect(updated.name, 'New');
      expect(updated.createdAt, site.createdAt);
    });
  });

  group('BrokenLink', () {
    test('toFirestore and fromFirestore are consistent', () async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.parse('2024-01-02T00:00:00Z');

      final ref = await firestore.collection('brokenLinks').add({
        'siteId': 's1',
        'userId': 'u1',
        'timestamp': Timestamp.fromDate(now),
        'url': 'https://example.com/404',
        'foundOn': 'https://example.com',
        'statusCode': 404,
        'error': 'Not Found',
        'linkType': 'external',
      });

      final snapshot = await ref.get();
      final link = BrokenLink.fromFirestore(snapshot);

      expect(link.id, ref.id);
      expect(link.statusCategory, 'Not Found');
      expect(link.linkType, LinkType.external);

      final map = link.toFirestore();
      expect(map['url'], 'https://example.com/404');
      expect(map['linkType'], 'external');
    });

    test('copyWith keeps unspecified fields', () {
      final now = DateTime.parse('2024-01-02T00:00:00Z');
      final link = BrokenLink(
        id: 'b1',
        siteId: 's1',
        userId: 'u1',
        timestamp: now,
        url: 'https://example.com/404',
        foundOn: 'https://example.com',
        statusCode: 404,
        error: 'Not Found',
        linkType: LinkType.internal,
      );

      final updated = link.copyWith(
        statusCode: 500,
        linkType: LinkType.external,
      );

      expect(updated.statusCode, 500);
      expect(updated.linkType, LinkType.external);
      expect(updated.url, link.url);
    });
  });

  group('LinkCheckResult', () {
    test('toFirestore and fromFirestore are consistent', () async {
      final firestore = FakeFirebaseFirestore();
      final timestamp = DateTime.parse('2024-01-03T00:00:00Z');

      final ref = await firestore.collection('linkCheckResults').add({
        'siteId': 's1',
        'checkedUrl': 'https://example.com',
        'checkedSitemapUrl': '/sitemap.xml',
        'sitemapStatusCode': 200,
        'timestamp': Timestamp.fromDate(timestamp),
        'totalLinks': 100,
        'brokenLinks': 2,
        'internalLinks': 80,
        'externalLinks': 20,
        'scanDuration': 1500,
        'pagesScanned': 50,
        'totalPagesInSitemap': 120,
        'scanCompleted': false,
        'newLastScannedPageIndex': 50,
        'pagesCompleted': 40,
        'currentBatchStart': 1,
        'currentBatchEnd': 100,
      });

      final snapshot = await ref.get();
      final result = LinkCheckResult.fromFirestore(snapshot);

      expect(result.id, ref.id);
      expect(result.checkedUrl, 'https://example.com');
      expect(result.sitemapStatusCode, 200);
      expect(result.pagesScanned, 50);
      expect(result.scanDuration.inMilliseconds, 1500);

      final map = result.toFirestore();
      expect(map['checkedUrl'], 'https://example.com');
      expect(map['scanDuration'], 1500);
      expect(map['pagesCompleted'], 40);
    });
  });
}
