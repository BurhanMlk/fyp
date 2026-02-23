import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import '../widgets/animated_blood_bg.dart';
import '../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack layout with animated background and content
      body: Stack(
        children: [
          // static gradient background underneath the animated blood cells
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.bgDeep, Color(0xFFFFEBEE)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ),
          // animated blood cells on top so their colors/effects remain visible
          Positioned.fill(child: AnimatedBloodBackground(cellCount: 9)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/blood_bridge.png',
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Center(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Icon(Icons.bloodtype, size: 36, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Welcome to Blood Bridge', style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('A Donor Recipient Connection App', style: TextStyle(color: Colors.black54, fontSize: 14)),
                    const SizedBox(height: 36),
                    Container(
                      width: 280,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white.withOpacity(0.9),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen())),
                              child: Text('Login', style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white.withOpacity(0.9),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen())),
                              child: Text('Register', style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
