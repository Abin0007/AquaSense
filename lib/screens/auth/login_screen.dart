import 'dart:math';
import 'package:aquasense/utils/page_transition.dart';
import 'package:flutter/material.dart';
import 'package:aquasense/screens/auth/register_screen.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:aquasense/screens/auth/components/glass_card.dart';
// FIX: Corrected the import path for the social login button.
import 'package:aquasense/screens/auth/components/social_login_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin { // Changed to TickerProviderStateMixin
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;

  late AnimationController _waveController;
  // NEW: Animation controller for the glowing button effect
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    // NEW: Initialize the glow controller
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _waveController.dispose();
    _glowController.dispose(); // NEW: Dispose the glow controller
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _authService.loginUser(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'email-not-verified') {
        _showVerificationDialog();
      } else {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Email Not Verified", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Please check your inbox and click the verification link to continue. Would you like us to resend the link?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                await _authService.sendEmailVerification();
                scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('A new verification link has been sent.')));
              } catch (e) {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Could not send link. Please try again.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text("Resend Link"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _handleAppleSignIn() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Feature Information", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Apple Sign-In is configured. Full activation requires a paid Apple Developer account.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Password", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your email to receive a password reset link.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            CustomInput(controller: resetEmailController, hintText: "Email", icon: Icons.email_outlined, glowAnimation: _glowController),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogContext).pop();
              if (resetEmailController.text.isNotEmpty) {
                try {
                  await _authService.sendPasswordResetEmail(email: resetEmailController.text.trim());
                  scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Password reset link sent! Check your email.')));
                } catch (e) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text("Send Link"),
          ),
        ],
      ),
    );
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacement(SlideFadeRoute(page: const RegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) => Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: CustomPaint(painter: WavePainter(offset: _waveController.value * 2 * pi)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Hero(tag: "logo", child: Icon(Icons.water_drop, size: 60, color: Colors.cyanAccent)),
                      const SizedBox(height: 16),
                      const Hero(tag: "title", child: Material(color: Colors.transparent, child: Text("Welcome Back", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)))),
                      const SizedBox(height: 24),
                      CustomInput(controller: emailController, hintText: "Email", icon: Icons.email_outlined, validator: (v) => v!.trim().isEmpty ? 'Email is required.' : null, glowAnimation: _glowController),
                      const SizedBox(height: 16),
                      CustomInput(controller: passwordController, hintText: "Password", icon: Icons.lock_outline, isPassword: true, validator: (v) => v!.trim().isEmpty ? 'Password is required.' : null, glowAnimation: _glowController),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isLoading)
                        const CircularProgressIndicator(color: Colors.cyanAccent)
                      else
                      // NEW: Added glowing effect to the login button
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.3 + (_glowController.value * 0.3)),
                                    blurRadius: 5 + (_glowController.value * 5),
                                    spreadRadius: 1 + (_glowController.value * 2),
                                  )
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                            child: const Text("Login", style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text("Or continue with", style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SocialLoginButton(assetName: 'assets/icons/google.svg', onPressed: _handleGoogleSignIn),
                          const SizedBox(width: 24),
                          SocialLoginButton(assetName: 'assets/icons/apple.svg', onPressed: _handleAppleSignIn),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(onPressed: _goToRegister, child: const Text("Don't have an account? Register", style: TextStyle(color: Colors.white70))),
                    ],
                  )
                  // ✅ FIX: Corrected the animation chaining as you requested.
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideY(begin: 0.5, curve: Curves.easeOut)
                      .then(delay: 100.ms),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double offset;
  WavePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Replaced deprecated withOpacity with a direct color definition.
    final paint = Paint()
      ..color = const Color.fromRGBO(64, 224, 208, 0.15)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..lineTo(0, size.height);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(i, size.height * 0.8 + 20 * sin(0.02 * i + offset));
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}