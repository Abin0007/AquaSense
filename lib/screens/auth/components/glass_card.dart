import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}