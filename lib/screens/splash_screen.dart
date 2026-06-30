import 'package:flutter/material.dart';
import '../widgets/animated_blood_bg.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  double _buttonScale = 1.0;

  @override
  void initState() {
    super.initState();
    // start fade-in
    Future.delayed(Duration(milliseconds: 80), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  void _goToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: AnimatedBloodBackground(cellCount: 9)),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 700),
                opacity: _opacity,
                curve: Curves.easeOut,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/images/blood_bridge.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stack) => CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Theme.of(context).primaryColor,
                                      child: const Icon(Icons.bloodtype, size: 32, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text('Blood Bridge', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(height: 4),
                              const Text('A Donor Recipient Connection App', style: TextStyle(color: Colors.black, fontSize: 13)),
                              const SizedBox(height: 14),
                              Card(
                                elevation: 0,
                                color: Colors.white.withOpacity(0.35),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                  child: Column(
                                    children: const [
                                      Text('Surah Al-Ma\'idah (Verse 32)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                                      SizedBox(height: 10),
                                      Text(
                                        'مَنْ قَتَلَ نَفْسًا بِغَيْرِ نَفْسٍ أَوْ فَسَادٍ فِي الْأَرْضِ فَكَأَنَّمَا قَتَلَ النَّاسَ جَمِيعًا ۖ وَمَنْ أَحْيَاهَا فَكَأَنَّمَا أَحْيَا النَّاسَ جَمِيعًا',
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black, fontFamilyFallback: ['Noto Naskh Arabic', 'Arial', 'Tahoma']),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        '"Whoever kills a soul unless for a soul or for corruption [done] in the land - it is as if he had slain mankind entirely. And whoever saves one - it is as if he had saved mankind entirely."',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              AnimatedScale(
                                scale: _buttonScale,
                                duration: const Duration(milliseconds: 120),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() => _buttonScale = 0.96);
                                      Future.delayed(const Duration(milliseconds: 90), () {
                                        if (mounted) {
                                          setState(() => _buttonScale = 1.0);
                                          _goToWelcome();
                                        }
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.black, width: 2),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      backgroundColor: Colors.white.withOpacity(0.9),
                                    ),
                                    child: const Text('Get Started', style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      print('Splash build error: $e\n$st');
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('An error occurred while loading the splash screen.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _goToWelcome, child: const Text('Continue')),
              ],
            ),
          ),
        ),
      );
    }
  }
}
