import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aquasense/main.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/screens/auth/components/glass_card.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isEmailVerified = false;
  bool _canResendEmail = false;
  Timer? _timer;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if (!_isEmailVerified) {
      _authService.sendEmailVerification();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser!.reload();
    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
    });

    if (_isEmailVerified) {
      _timer?.cancel();
      // FIX: Check if the widget is still mounted before navigating.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      setState(() => _canResendEmail = false);
      await Future.delayed(const Duration(seconds: 30));
      // FIX: Check if mounted before updating state.
      if (mounted) {
        setState(() => _canResendEmail = true);
      }
    } catch (e) {
      // FIX: Check if mounted before showing SnackBar.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen implementation remains the same
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.email_outlined, size: 80, color: Colors.cyanAccent),
                    const SizedBox(height: 24),
                    const Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A verification link has been sent to:\n${FirebaseAuth.instance.currentUser?.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'Waiting for verification...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _canResendEmail ? _resendVerificationEmail : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canResendEmail ? Colors.cyanAccent : Colors.grey,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Resend Email'),
                    ),
                    TextButton(
                      onPressed: () => _authService.logoutUser(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    )
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