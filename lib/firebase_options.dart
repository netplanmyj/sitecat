import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Environment-aware Firebase options
///
/// Uses production Firebase project for release/profile builds,
/// and development Firebase project for debug builds.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // In release/profile mode, use production Firebase project
    if (kReleaseMode) {
      return prod.DefaultFirebaseOptions.currentPlatform;
    }

    // In debug mode, use development Firebase project
    return dev.DefaultFirebaseOptions.currentPlatform;
  }
}
