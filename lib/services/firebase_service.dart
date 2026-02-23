import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../firebase_options.dart';

class FirebaseService {
  /// true when Firebase.initializeApp() completed successfully.
  static bool initialized = false;
  /// Initialize Firebase with proper configuration
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      initialized = true;
      print('✅ Firebase initialized successfully on ${kIsWeb ? "web" : "mobile"}');
    } catch (e) {
      // In development it's okay to continue without Firebase configured.
      print('⚠️ Firebase initialization failed: $e');
      initialized = false;
    }
  }
}
