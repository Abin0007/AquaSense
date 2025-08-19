import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:aquasense/main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExplainerScreen extends StatefulWidget {
  const ExplainerScreen({super.key});

  @override
  State<ExplainerScreen> createState() => _ExplainerScreenState();
}

class _ExplainerScreenState extends State<ExplainerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _buttonController;
  // 1. Create a PageController
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _pageController.dispose(); // Don't forget to dispose the controller
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _buttonController.forward();
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    await _buttonController.reverse();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthWrapper(),
          transitionDuration: const Duration(milliseconds: 1000),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 2. Wrap the PageView in a Stack
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView(
            controller: _pageController, // Assign the controller
            children: [
              _buildWelcomePage(),
              _buildAnimationPage(),
            ],
          ),

          // 3. Conditionally show buttons only for the web platform
          if (kIsWeb)
            Positioned(
              bottom: 30,
              left: 30,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),

          if (kIsWeb)
            Positioned(
              bottom: 30,
              right: 30,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF152D4E), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          const Icon(Icons.water_drop_outlined, size: 100, color: Colors.cyanAccent),
          const SizedBox(height: 24),
          const Text(
            "Welcome to AquaSense",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            "Your personal platform for smart water supply and management.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const Spacer(flex: 3),
          // Show swipe hint only on non-web platforms
          if (!kIsWeb)
            const Text(
              "Swipe Left to Continue",
              style: TextStyle(fontSize: 16, color: Colors.white54),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .slideX(
                begin: 0,
                end: 0.1,
                duration: 1500.ms,
                curve: Curves.easeInOut)
                .then(delay: 500.ms)
                .shimmer(duration: 1000.ms, color: const Color.fromRGBO(100, 255, 218, 0.5)),
          const SizedBox(height: 24),
        ]
            .animate(interval: 200.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.2, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildAnimationPage() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C5364), Color(0xFF0F2027)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Lottie.asset('assets/animations/water_management_explainer.json', height: 300),
          const SizedBox(height: 24),
          const Text(
            "Sustainable Water,\nSustainable Future",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            "Join us in making every drop count through smart management and conservation.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const Spacer(),
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: () => _buttonController.reverse(),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 0.95).animate(
                CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.cyanAccent,
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(100, 255, 218, 0.5), blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ]
            .animate(interval: 200.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.2, curve: Curves.easeOut),
      ),
    );
  }
}