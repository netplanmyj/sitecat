import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Environment-aware Firebase options
///
/// Uses production Firebase project for release builds,
/// and development Firebase project for debug/profile builds.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // In release mode, use production Firebase project
    if (const bool.fromEnvironment('dart.vm.product')) {
      return prod.DefaultFirebaseOptions.currentPlatform;
    }

    // In debug/profile mode, use development Firebase project
    return dev.DefaultFirebaseOptions.currentPlatform;
  }
}
