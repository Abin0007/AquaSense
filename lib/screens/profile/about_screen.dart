import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // You can fetch this from pubspec.yaml later if needed
    const appVersion = "1.0.0";

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('About AquaSense'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/water_management_explainer.json',
                height: 250,
              ),
              const SizedBox(height: 24),
              const Text(
                'AquaSense',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Version $appVersion',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Smart Water Supply and Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This application is designed to modernize water distribution systems, ensuring transparency, efficiency, and citizen engagement. Thank you for being a part of a sustainable water future.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const Text(
                'Developed with ❤️',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}