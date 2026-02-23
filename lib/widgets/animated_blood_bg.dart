import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedBloodBackground extends StatefulWidget {
  final int cellCount;
  const AnimatedBloodBackground({super.key, this.cellCount = 8});

  @override
  _AnimatedBloodBackgroundState createState() =>
      _AnimatedBloodBackgroundState();
}

class _AnimatedBloodBackgroundState extends State<AnimatedBloodBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value * 2 * pi;
            List<Widget> cells = [];
            final rand = Random(42);
            for (int i = 0; i < widget.cellCount; i++) {
              final seed = rand.nextDouble() * 2 * pi + i;
              final cx = (0.2 + 0.6 * ((sin(t + seed * 0.7) + 1) / 2)) * w;
              final cy = (0.15 + 0.7 * ((cos(t * 0.9 + seed) + 1) / 2)) * h;
              final baseSize = lerpDouble(
                40,
                120,
                (i / (widget.cellCount - 1)).clamp(0.0, 1.0),
              )!;
              final pulse = 0.85 + 0.3 * sin(t * (0.8 + i * 0.1) + seed);
              final size = baseSize * pulse;
              final depth = 0.5 + 0.5 * ((sin(t * 0.6 + seed) + 1) / 2);
              final rotate = 0.2 * sin(t + seed * 0.5);

              cells.add(
                Positioned(
                  left: cx - size / 2,
                  top: cy - size / 2,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(0.0, 0.0, depth * 40)
                      ..rotateZ(rotate),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: lerpDouble(0.6, 0.95, depth)!,
                      child: _BloodCell(size: size, depth: depth),
                    ),
                  ),
                ),
              );
            }

            return Stack(children: cells);
          },
        );
      },
    );
  }
}

class _BloodCell extends StatelessWidget {
  final double size;
  final double depth;
  const _BloodCell({required this.size, required this.depth});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 0,
        maxWidth: size,
        minHeight: 0,
        maxHeight: size * 0.66,
      ),
      child: Container(
        width: size,
        height: size * 0.66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size),
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.3),
            radius: 0.9,
            colors: [
              // soften the blood cell colors so the animated background isn't near-black
              Color.lerp(Colors.red.shade300, Colors.red.shade700, depth)!,
              Colors.red.shade400.withValues(alpha: 0.95),
              Colors.red.shade300.withValues(alpha: 0.85),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18 * depth),
              blurRadius: 18 * depth,
              offset: Offset(0, 6 * depth),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: Offset(-2, -2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.35,
            height: size * 0.2,
            decoration: BoxDecoration(
              color: Colors.red.shade700.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a = a ?? 0.0;
  b = b ?? 0.0;
  return a + (b - a) * t;
}
