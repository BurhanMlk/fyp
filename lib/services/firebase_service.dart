import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../firebase_options.dart' show DefaultFirebaseOptions;

class FirebaseService {
  /// true when Firebase.initializeApp() completed successfully.
  static bool initialized = false;

  /// Initialize Firebase with proper configuration
  static Future<void> init() async {
    try {
      // Use generated Firebase options (works for web and mobile).
      final options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: options);
      initialized = true;
      print('✅ Firebase initialized successfully on ${kIsWeb ? "web" : "mobile"}');
    } catch (e) {
      // In development it's okay to continue without Firebase configured.
      print('⚠️ Firebase initialization failed: $e');
      initialized = false;
    }
  }
}
