import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SiteTransactionException implements Exception {
  final String code;
  final String? message;
  final Map<String, dynamic>? details;
  SiteTransactionException({required this.code, this.message, this.details});
  @override
  String toString() =>
      'SiteTransactionException(code: $code, message: $message, details: $details)';
}

/// Service wrapper for the createSiteTransaction callable.
/// Default implementation uses Firebase Functions. Tests can inject fakes.
class SiteTransactionService {
  Future<Map<String, dynamic>> createSiteTransaction({
    required String url,
    required String name,
    String? sitemapUrl,
    List<String> excludedPaths = const [],
    int? checkInterval,
  }) async {
    try {
      final app = Firebase.app('sitecat-current');
      final auth = FirebaseAuth.instanceFor(app: app);
      final user = auth.currentUser;
      if (user == null) {
        throw SiteTransactionException(
          code: 'unauthenticated',
          message: 'unauthenticated',
        );
      }

      final functions = FirebaseFunctions.instanceFor(
        app: app,
        region: 'us-central1',
      );
      final callable = functions.httpsCallable('createSiteTransaction');
      final result = await callable.call<Map<String, dynamic>>({
        'url': url,
        'name': name,
        'sitemapUrl': sitemapUrl,
        'excludedPaths': excludedPaths,
        'checkInterval': checkInterval,
      });
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      // Propagate as domain exception with details for provider handling
      throw SiteTransactionException(
        code: e.code,
        message: e.message,
        details: e.details as Map<String, dynamic>?,
      );
    }
  }
}
