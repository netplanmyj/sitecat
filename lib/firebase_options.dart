import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Environment-aware Firebase options
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Debug logging to verify which env is selected
    debugPrint('🔍 Environment detection:');
    debugPrint('  - kDebugMode: $kDebugMode');
    debugPrint('  - kProfileMode: $kProfileMode');
    debugPrint('  - kReleaseMode: $kReleaseMode');

    // kReleaseMode: true in --release, false in --debug/--profile
    if (kReleaseMode) {
      debugPrint('🔴 Firebase: Using PRODUCTION (sitecat-prod)');
      return prod.DefaultFirebaseOptions.currentPlatform;
    } else {
      debugPrint('🟢 Firebase: Using DEVELOPMENT (sitecat-dev)');
      return dev.DefaultFirebaseOptions.currentPlatform;
    }
  }
}
