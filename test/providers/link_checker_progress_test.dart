import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/providers/link_checker_progress.dart';

void main() {
  late LinkCheckerProgress progress;

  setUp(() {
    progress = LinkCheckerProgress();
  });

  group('LinkCheckerProgress', () {
    // Basic Progress Tracking Tests
    group('Basic Progress Tracking', () {
      test('setCheckedCount and getCheckedCount', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        expect(progress.getCheckedCount(siteId), equals(50));
      });

      test('setTotalCount and getTotalCount', () {
        const String siteId = 'site-1';
        progress.setTotalCount(siteId, 100);
        expect(progress.getTotalCount(siteId), equals(100));
      });

      test('getCheckedCount returns 0 for non-existent site', () {
        expect(progress.getCheckedCount('non-existent'), equals(0));
      });

      test('getTotalCount returns 0 for non-existent site', () {
        expect(progress.getTotalCount('non-existent'), equals(0));
      });
    });

    // Progress Calculation Tests
    group('Progress Calculation', () {
      test('getProgress returns decimal value (0.0 to 1.0)', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        progress.setTotalCount(siteId, 100);

        final result = progress.getProgress(siteId);
        expect(result, equals(0.5));
      });

      test('getProgress returns 0.0 when total is 0', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        progress.setTotalCount(siteId, 0);

        final result = progress.getProgress(siteId);
        expect(result, equals(0.0));
      });

      test('getProgressPercentage returns integer percentage', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 75);
        progress.setTotalCount(siteId, 100);

        final result = progress.getProgressPercentage(siteId);
        expect(result, equals(75));
      });

      test('getProgressPercentage returns 0 when total is 0', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        progress.setTotalCount(siteId, 0);

        final result = progress.getProgressPercentage(siteId);
        expect(result, equals(0));
      });

      test('getProgressPercentage rounds down correctly', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 33);
        progress.setTotalCount(siteId, 100);

        // 33/100 = 0.33 = 33%
        final result = progress.getProgressPercentage(siteId);
        expect(result, equals(33));
      });
    });

    // External Links Progress Tests
    group('External Links Progress', () {
      test('setExternalLinksProgress and getExternalProgress', () {
        const String siteId = 'site-1';
        progress.setExternalLinksProgress(siteId, 20, 50);

        final result = progress.getExternalProgress(siteId);
        expect(result, equals(0.4)); // 20/50
      });

      test('getExternalProgress returns 0.0 when total is 0', () {
        const String siteId = 'site-1';
        progress.setExternalLinksProgress(siteId, 20, 0);

        final result = progress.getExternalProgress(siteId);
        expect(result, equals(0.0));
      });

      test('getExternalProgressPercentage returns integer percentage', () {
        const String siteId = 'site-1';
        progress.setExternalLinksProgress(siteId, 30, 100);

        final result = progress.getExternalProgressPercentage(siteId);
        expect(result, equals(30));
      });

      test('getExternalProgressPercentage for non-existent site', () {
        final result = progress.getExternalProgressPercentage('non-existent');
        expect(result, equals(0));
      });
    });

    // External Links Processing Flag Tests
    group('External Links Processing Flag', () {
      test('setIsProcessingExternalLinks and isProcessingExternalLinks', () {
        const String siteId = 'site-1';
        progress.setIsProcessingExternalLinks(siteId, true);
        expect(progress.isProcessingExternalLinks(siteId), isTrue);

        progress.setIsProcessingExternalLinks(siteId, false);
        expect(progress.isProcessingExternalLinks(siteId), isFalse);
      });

      test('isProcessingExternalLinks returns false for non-existent site', () {
        expect(progress.isProcessingExternalLinks('non-existent'), isFalse);
      });
    });

    // Cancel Request Tests
    group('Cancel Request', () {
      test('setCancelRequested and isCancelRequested', () {
        const String siteId = 'site-1';
        progress.setCancelRequested(siteId, true);
        expect(progress.isCancelRequested(siteId), isTrue);

        progress.setCancelRequested(siteId, false);
        expect(progress.isCancelRequested(siteId), isFalse);
      });

      test('isCancelRequested returns false for non-existent site', () {
        expect(progress.isCancelRequested('non-existent'), isFalse);
      });
    });

    // Precalculated Page Count Tests
    group('Precalculated Page Count', () {
      test('setPrecalculatedPageCount and getPrecalculatedPageCount', () {
        const String siteId = 'site-1';
        progress.setPrecalculatedPageCount(siteId, 250);
        expect(progress.getPrecalculatedPageCount(siteId), equals(250));
      });

      test('getPrecalculatedPageCount returns null for non-existent site', () {
        expect(progress.getPrecalculatedPageCount('non-existent'), isNull);
      });

      test('clearPrecalculatedPageCount removes the value', () {
        const String siteId = 'site-1';
        progress.setPrecalculatedPageCount(siteId, 250);
        expect(progress.getPrecalculatedPageCount(siteId), isNotNull);

        progress.clearPrecalculatedPageCount(siteId);
        expect(progress.getPrecalculatedPageCount(siteId), isNull);
      });

      test('setPrecalculatedPageCount with null', () {
        const String siteId = 'site-1';
        progress.setPrecalculatedPageCount(siteId, null);
        expect(progress.getPrecalculatedPageCount(siteId), isNull);
      });
    });

    // Progress Snapshot Tests
    group('Progress Snapshot', () {
      test('getProgressSnapshot returns complete snapshot', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        progress.setTotalCount(siteId, 100);
        progress.setExternalLinksProgress(siteId, 20, 50);
        progress.setIsProcessingExternalLinks(siteId, true);
        progress.setPrecalculatedPageCount(siteId, 250);

        final snapshot = progress.getProgressSnapshot(siteId);

        expect(snapshot['checkedCount'], equals(50));
        expect(snapshot['totalCount'], equals(100));
        expect(snapshot['externalChecked'], equals(20));
        expect(snapshot['externalTotal'], equals(50));
        expect(snapshot['isProcessingExternal'], isTrue);
        expect(snapshot['precalculatedPageCount'], equals(250));
      });

      test('getProgressSnapshot for non-existent site returns defaults', () {
        final snapshot = progress.getProgressSnapshot('non-existent');

        expect(snapshot['checkedCount'], equals(0));
        expect(snapshot['totalCount'], equals(0));
        expect(snapshot['externalChecked'], equals(0));
        expect(snapshot['externalTotal'], equals(0));
        expect(snapshot['isProcessingExternal'], isFalse);
      });

      test('restoreProgressSnapshot restores all values', () {
        const String siteId = 'site-1';
        final snapshot = {
          'checkedCount': 75,
          'totalCount': 150,
          'externalChecked': 30,
          'externalTotal': 80,
          'isProcessingExternal': true,
          'precalculatedPageCount': 300,
        };

        progress.restoreProgressSnapshot(siteId, snapshot);

        expect(progress.getCheckedCount(siteId), equals(75));
        expect(progress.getTotalCount(siteId), equals(150));
        expect(progress.getExternalProgress(siteId), equals(30 / 80));
        expect(progress.isProcessingExternalLinks(siteId), isTrue);
        expect(progress.getPrecalculatedPageCount(siteId), equals(300));
      });

      test('restoreProgressSnapshot handles null values gracefully', () {
        const String siteId = 'site-1';
        final snapshot = {
          'checkedCount': 50,
          'totalCount': 100,
          'externalChecked': null,
          'externalTotal': null,
          'isProcessingExternal': null,
          'precalculatedPageCount': null,
        };

        progress.restoreProgressSnapshot(siteId, snapshot);

        expect(progress.getCheckedCount(siteId), equals(50));
        expect(progress.getTotalCount(siteId), equals(100));
        expect(progress.getPrecalculatedPageCount(siteId), isNull);
      });
    });

    // Reset Tests
    group('Reset and Clear', () {
      test('resetProgress clears all data for a site', () {
        const String siteId = 'site-1';
        progress.setCheckedCount(siteId, 50);
        progress.setTotalCount(siteId, 100);
        progress.setExternalLinksProgress(siteId, 20, 50);
        progress.setIsProcessingExternalLinks(siteId, true);
        progress.setCancelRequested(siteId, true);
        progress.setPrecalculatedPageCount(siteId, 250);

        progress.resetProgress(siteId);

        expect(progress.getCheckedCount(siteId), equals(0));
        expect(progress.getTotalCount(siteId), equals(0));
        expect(progress.isProcessingExternalLinks(siteId), isFalse);
        expect(progress.isCancelRequested(siteId), isFalse);
        expect(progress.getPrecalculatedPageCount(siteId), isNull);
      });

      test('clearAll clears data for all sites', () {
        progress.setCheckedCount('site-1', 50);
        progress.setCheckedCount('site-2', 30);
        progress.setTotalCount('site-1', 100);
        progress.setTotalCount('site-2', 80);

        progress.clearAll();

        expect(progress.getCheckedCount('site-1'), equals(0));
        expect(progress.getCheckedCount('site-2'), equals(0));
        expect(progress.getTotalCount('site-1'), equals(0));
        expect(progress.getTotalCount('site-2'), equals(0));
      });
    });

    // Statistics Tests
    group('Progress Statistics', () {
      test('getProgressStats returns correct statistics', () {
        progress.setCheckedCount('site-1', 50);
        progress.setTotalCount('site-1', 100);
        progress.setCheckedCount('site-2', 30);
        progress.setTotalCount('site-2', 80);
        progress.setIsProcessingExternalLinks('site-1', true);
        progress.setCancelRequested('site-2', true);
        progress.setPrecalculatedPageCount('site-1', 250);

        final stats = progress.getProgressStats();

        expect(stats['trackedSites'], equals(2));
        expect(stats['totalCheckedCount'], equals(80)); // 50 + 30
        expect(stats['totalTotalCount'], equals(180)); // 100 + 80
        expect(stats['sitesProcessingExternal'], equals(1));
        expect(stats['sitesWithCancelRequest'], equals(1));
        expect(stats['precalculatedSites'], equals(1));
      });

      test('getProgressStats with empty progress', () {
        final stats = progress.getProgressStats();

        expect(stats['trackedSites'], equals(0));
        expect(stats['totalCheckedCount'], equals(0));
        expect(stats['totalTotalCount'], equals(0));
      });
    });

    // Complex Scenarios Tests
    group('Complex Scenarios', () {
      test('multiple sites with different progress states', () {
        // Site 1: 50% complete with external links processing
        progress.setCheckedCount('site-1', 50);
        progress.setTotalCount('site-1', 100);
        progress.setExternalLinksProgress('site-1', 10, 30);
        progress.setIsProcessingExternalLinks('site-1', true);

        // Site 2: 75% complete, cancel requested
        progress.setCheckedCount('site-2', 75);
        progress.setTotalCount('site-2', 100);
        progress.setCancelRequested('site-2', true);

        expect(progress.getProgressPercentage('site-1'), equals(50));
        expect(progress.getExternalProgressPercentage('site-1'), equals(33));
        expect(progress.getProgressPercentage('site-2'), equals(75));
        expect(progress.isCancelRequested('site-2'), isTrue);
      });

      test('snapshot and restore preserves all state', () {
        const String siteId = 'site-1';

        // Set up initial state
        progress.setCheckedCount(siteId, 60);
        progress.setTotalCount(siteId, 120);
        progress.setExternalLinksProgress(siteId, 25, 60);
        progress.setIsProcessingExternalLinks(siteId, true);
        progress.setPrecalculatedPageCount(siteId, 300);

        // Get snapshot
        final snapshot = progress.getProgressSnapshot(siteId);

        // Reset and restore
        progress.resetProgress(siteId);
        expect(progress.getCheckedCount(siteId), equals(0));

        progress.restoreProgressSnapshot(siteId, snapshot);

        expect(progress.getCheckedCount(siteId), equals(60));
        expect(progress.getTotalCount(siteId), equals(120));
        expect(progress.getExternalProgress(siteId), closeTo(25 / 60, 0.01));
        expect(progress.isProcessingExternalLinks(siteId), isTrue);
        expect(progress.getPrecalculatedPageCount(siteId), equals(300));
      });
    });
  });
}
