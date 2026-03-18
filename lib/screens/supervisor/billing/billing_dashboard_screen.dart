import 'package:aquasense/screens/supervisor/billing/manual_search_screen.dart';
import 'package:aquasense/screens/supervisor/qr_scanner_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BillingDashboardScreen extends StatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  State<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends State<BillingDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Generate Bill'),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select a method to find the user and generate their monthly bill.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 50),
              _buildScanQRButton(context),
              const SizedBox(height: 20),
              _buildManualSearchButton(context),
            ]
                .animate(interval: 200.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.5, curve: Curves.easeOut),
          ),
        ),
      ),
    );
  }

  Widget _buildScanQRButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent
                    .withValues(alpha: 0.3 + (_glowController.value * 0.4)),
                blurRadius: 10 + (_glowController.value * 10),
                spreadRadius: 2 + (_glowController.value * 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context)
              .push(SlideFadeRoute(page: const QrScannerScreen()));
        },
        icon: const Icon(Icons.qr_code_scanner_outlined, size: 28),
        label: const Text('Scan Meter QR'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: Colors.cyanAccent,
          foregroundColor: Colors.black,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildManualSearchButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context)
            .push(SlideFadeRoute(page: const ManualSearchScreen()));
      },
      icon: const Icon(Icons.search),
      label: const Text('Manual User Search'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}
