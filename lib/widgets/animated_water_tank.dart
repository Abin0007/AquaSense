import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sensors_plus/sensors_plus.dart';

class AnimatedWaterTank extends StatefulWidget {
  final int waterLevel;
  final String tankName;

  const AnimatedWaterTank({
    super.key,
    required this.waterLevel,
    required this.tankName,
  });

  @override
  State<AnimatedWaterTank> createState() => _AnimatedWaterTankState();
}

class _AnimatedWaterTankState extends State<AnimatedWaterTank>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  StreamSubscription? _accelerometerSubscription;
  double _tiltX = 0.0;
  double _smoothedTiltX = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() {
          _tiltX = event.x;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Color _getWaterColor() {
    if (widget.waterLevel <= 20) return Colors.red.shade400;
    if (widget.waterLevel < 40) return Colors.amber.shade400;
    return const Color(0xFF38B6FF);
  }

  @override
  Widget build(BuildContext context) {
    final Color waterColor = _getWaterColor();

    double targetTilt = 0.0;
    // --- MODIFIED: Increased sensitivity by lowering the dead zone threshold ---
    if (_tiltX.abs() > 0.75) { // Was 1.0, now reacts to smaller tilts
      targetTilt = _tiltX.clamp(-4.0, 4.0);
    }
    _smoothedTiltX = _smoothedTiltX * 0.9 + targetTilt * 0.1;


    return Animate(
      effects: [const FadeEffect(), ScaleEffect(curve: Curves.easeOutCubic, delay: 200.ms)],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.tankName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.waterLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '%',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F2027), Color(0xFF203A43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _WavePainter(
                            animationValue: _waveController.value,
                            waterLevelPercent: widget.waterLevel / 100.0,
                            waterColor: waterColor,
                            tiltEffect: _smoothedTiltX,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
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

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double waterLevelPercent;
  final Color waterColor;
  final double tiltEffect;

  _WavePainter({
    required this.animationValue,
    required this.waterLevelPercent,
    required this.waterColor,
    required this.tiltEffect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * (1 - waterLevelPercent);
    // --- MODIFIED: Increased sensitivity multiplier ---
    final tiltOffset = (size.width / 2) * (tiltEffect / 4.0) * 0.8; // Was 0.7

    final startY = baseY - tiltOffset;
    final endY = baseY + tiltOffset;

    final waterPath = Path();
    waterPath.moveTo(0, startY);

    for (double i = 0; i <= size.width; i++) {
      final percent = i / size.width;
      final currentY = startY + (endY - startY) * percent;
      final waveOffset = math.sin((i / 40) + (animationValue * 2 * math.pi)) * 5;
      waterPath.lineTo(i, currentY + waveOffset);
    }

    waterPath.lineTo(size.width, size.height);
    waterPath.lineTo(0, size.height);
    waterPath.close();

    final paint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(waterPath, paint);
  }


  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
          oldDelegate.tiltEffect != tiltEffect ||
          oldDelegate.waterLevelPercent != waterLevelPercent;
}