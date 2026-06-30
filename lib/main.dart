import 'package:flutter/material.dart';
import 'screens/donors/donor_search_screen.dart';
import 'screens/emergency/emergency_request_screen.dart';
import 'services/firebase_service.dart';
import 'theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/blood_bridge_chatbot.dart';
import 'dart:async';

Future<void> main() async {
  // Catch all uncaught errors and print stack traces for debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Print to console for web host to show
    print('🔴 FlutterError caught: ${details.exception}');
    print('📍 Stack: ${details.stack}');
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      print('⚙️ Initializing Firebase...');
      await FirebaseService.init();
      print('✅ Firebase initialized successfully');
    } catch (e, st) {
      print('⚠️ Firebase initialization failed: $e');
      print('📍 Stack trace: $st');
      print('App will run without Firebase features');
    }

    print('🚀 Starting Blood Bridge App...');
    runApp(const BloodBridgeApp());
  }, (error, stack) {
    print('🔴 Uncaught zone error: $error');
    print('📍 Stack: $stack');
  });
}

class BloodBridgeApp extends StatelessWidget {
  const BloodBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('📱 Building MaterialApp...');
    return MaterialApp(
      title: 'Blood Bridge',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/donor_search': (_) => DonorSearchScreen(),
        '/emergency': (_) => EmergencyRequestScreen(),
      },
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            const Positioned.fill(child: BloodBridgeChatbot()),
          ],
        );
      },
    );
  }
}
