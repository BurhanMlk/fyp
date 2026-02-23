import 'package:flutter/material.dart';

/// Custom loading indicator using Blood Bridge logo with rotation animation
class BloodBridgeLoader extends StatefulWidget {
  final double size;
  final Duration duration;
  
  const BloodBridgeLoader({
    super.key,
    this.size = 60.0,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<BloodBridgeLoader> createState() => _BloodBridgeLoaderState();
}

class _BloodBridgeLoaderState extends State<BloodBridgeLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/blood_bridge.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Icon(
              Icons.bloodtype,
              size: widget.size * 0.6,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
