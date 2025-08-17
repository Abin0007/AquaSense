import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedWaveBackground extends StatefulWidget {
  final List<Color> gradientColors;

  // FIX: Use super.key for constructor
  const AnimatedWaveBackground({
    super.key,
    required this.gradientColors,
  });

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter: _WavePainter(offset: _waveController.value * 2 * math.pi),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double offset;
  _WavePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Replaced deprecated withOpacity
    final paint = Paint()
      ..color = const Color.fromRGBO(64, 224, 208, 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.8);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height * 0.8 + 20 * math.sin(0.02 * i + offset),
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}