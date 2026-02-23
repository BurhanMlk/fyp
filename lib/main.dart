import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/login_screen.dart';
import 'screens/donors/donor_search_screen.dart';
import 'screens/emergency/emergency_request_screen.dart';
import 'services/firebase_service.dart';
import 'theme.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  
  // Initialize Firebase with error handling
  try {
    await FirebaseService.init();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
    print('App will run without Firebase features');
  }
  
  print('🚀 Starting Blood Bridge App...');
  runApp(const BloodBridgeApp());
}

class BloodBridgeApp extends StatelessWidget {
  const BloodBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('📱 Building MaterialApp...');
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
          // Trigger hot reload by calling reassemble
          print('🔄 Hot reload triggered via "r" key');
          WidgetsBinding.instance.reassembleApplication();
        }
      },
      child: MaterialApp(
        title: 'Blood Bridge',
        theme: AppTheme.lightTheme(),
        debugShowCheckedModeBanner: false,
        home: const WelcomeScreen(),
        routes: {
          '/donor_search': (_) => DonorSearchScreen(),
          '/emergency': (_) => EmergencyRequestScreen(),
        },
      ),
    );
  }
}
