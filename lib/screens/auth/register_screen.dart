import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aquasense/screens/auth/login_screen.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/utils/location_service.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:aquasense/screens/auth/components/glass_card.dart';
import 'package:aquasense/widgets/otp_input.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:lottie/lottie.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// FIX: Changed to TickerProviderStateMixin to support multiple AnimationControllers.
class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  final AuthService _authService = AuthService();
  bool isEmailVerified = false;
  bool isPhoneVerified = false;
  String fullPhoneNumber = '';
  String? _phoneVerificationId;

  final LocationService _locationService = LocationService();
  final List<String> _states = [];
  final List<String> _districts = [];
  final List<String> _wards = [];

  String? selectedState;
  String? selectedDistrict;
  String? selectedWard;

  late AnimationController _waveController;
  // NEW: Animation controller for the glowing button effect
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    // NEW: Initialize the glow controller
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _loadStates();
    emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    emailController.removeListener(_onEmailChanged);
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _waveController.dispose();
    _glowController.dispose(); // NEW: Dispose the glow controller
    super.dispose();
  }

  void _onEmailChanged() {
    if (isEmailVerified) {
      setState(() => isEmailVerified = false);
    }
  }

  Future<void> _loadStates() async {
    if(!mounted) return;
    final loadedStates = await _locationService.getStates();
    if(mounted) {
      setState(() {
        _states.addAll(loadedStates);
      });
    }
  }


  void _verifyEmailFormat() {
    FocusScope.of(context).unfocus();
    if (emailController.text.trim().isEmpty || !RegExp(r"^[a-zA-Z][a-zA-Z0-9._-]*@[a-zA-Z0-9-]+\.[a-zA-Z]{2,4}$").hasMatch(emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email to verify.')));
      return;
    }
    setState(() => isEmailVerified = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Email format is valid. The verification link will be sent upon registration.')));
  }

  Future<void> _verifyPhoneNumber() async {
    FocusScope.of(context).unfocus();
    if (fullPhoneNumber.isEmpty || phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit phone number.')));
      return;
    }
    setState(() => isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await _authService.sendOtp(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId, resendToken) {
        if(!mounted) return;
        setState(() => isLoading = false);
        _phoneVerificationId = verificationId;
        _showOtpDialog();
      },
      verificationFailed: (e) {
        if(!mounted) return;
        setState(() => isLoading = false);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Phone verification failed.')));
      },
    );
  }

  void _showOtpDialog() {
    final otpControllers = List.generate(6, (index) => TextEditingController());
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          return AlertDialog(
            backgroundColor: const Color(0xFF2C5364),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Verify Phone Number", style: TextStyle(color: Colors.white)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Enter the 6-digit code sent to your phone.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (index) => OtpInput(controller: otpControllers[index], autoFocus: index == 0))),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final otp = otpControllers.map((e) => e.text).join();
                    if (otp.length == 6 && _phoneVerificationId != null) {
                      await _authService.verifyOtp(verificationId: _phoneVerificationId!, otp: otp);
                      if (mounted) {
                        setState(() => isPhoneVerified = true);
                        navigator.pop();
                        scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Phone number verified successfully!')));
                      }
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                child: const Text("Verify"),
              )
            ],
          );
        }
    );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (!isEmailVerified) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please validate your email address.')));
      return;
    }
    if (!isPhoneVerified) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please verify your phone number.')));
      return;
    }
    if (selectedWard == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please select your ward.')));
      return;
    }

    setState(() => isLoading = true);
    try {
      await _authService.registerUser(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        wardId: selectedWard!,
        phoneNumber: fullPhoneNumber,
      );
      if (mounted) _showSuccessDialog();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Registration Successful!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Please check your email to verify your account before logging in.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goToLogin();
            },
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canRegister = isEmailVerified && isPhoneVerified;
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: GlassCard(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Hero(tag: "logo", child: Icon(Icons.water_drop, size: 60, color: Colors.cyanAccent)),
                      const SizedBox(height: 16),
                      const Hero(tag: "title", child: Material(color: Colors.transparent, child: Text("Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)))),
                      const SizedBox(height: 24),
                      CustomInput(
                        controller: nameController,
                        hintText: "Full Name",
                        icon: Icons.person_outline,
                        glowAnimation: _glowController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Full Name is required.';
                          if (value.trim().length < 3) return 'Name must be at least 3 characters.';
                          if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value)) return 'Please enter a valid name (letters only).';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildVerifiableField(
                        controller: emailController,
                        hintText: "Email",
                        icon: Icons.email_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email is required.';
                          if (!RegExp(r"^[a-zA-Z][a-zA-Z0-9._-]*@[a-zA-Z0-9-]+\.[a-zA-Z]{2,4}$").hasMatch(value)) return 'Enter a valid email address.';
                          return null;
                        },
                        isVerified: isEmailVerified,
                        onVerify: _verifyEmailFormat,
                        buttonText: "Validate",
                      ),
                      const SizedBox(height: 16),
                      _buildVerifiablePhoneField(),
                      const SizedBox(height: 16),
                      _buildWardSelectionField(),
                      const SizedBox(height: 16),
                      CustomInput(
                        controller: passwordController,
                        hintText: "Password",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        glowAnimation: _glowController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password is required.';
                          if (value.length < 8) return 'Password must be at least 8 characters.';
                          if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$').hasMatch(value)) return 'Use uppercase, number & symbol.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomInput(
                        controller: confirmPasswordController,
                        hintText: "Confirm Password",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        glowAnimation: _glowController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please confirm your password.';
                          if (value != passwordController.text) return 'Passwords do not match.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      isLoading
                          ? const CircularProgressIndicator(color: Colors.cyanAccent)
                          : ElevatedButton(
                        onPressed: canRegister ? _register : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: canRegister ? Colors.cyanAccent : Colors.grey[700],
                          foregroundColor: canRegister ? Colors.black : Colors.grey[400],
                        ),
                        child: const Text("Register", style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _goToLogin, child: const Text("Already have an account? Login", style: TextStyle(color: Colors.white70))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiableField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?)? validator,
    required bool isVerified,
    required VoidCallback onVerify,
    required String buttonText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: CustomInput(controller: controller, hintText: hintText, icon: icon, validator: validator, glowAnimation: _glowController,)),
        if (isVerified)
          const Padding(
            padding: EdgeInsets.only(top: 14.0, left: 8.0),
            child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 30),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              height: 58,
              child: OutlinedButton(
                onPressed: onVerify,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(buttonText),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifiablePhoneField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildInternationalPhoneField()),
        if (isPhoneVerified)
          const Padding(
            padding: EdgeInsets.only(top: 14.0, left: 8.0),
            child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 30),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              height: 58,
              child: OutlinedButton(
                onPressed: _verifyPhoneNumber,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Get OTP"),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInternationalPhoneField() {
    return IntlPhoneField(
      controller: phoneController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Phone Number',
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.cyanAccent)),
        counterText: "",
      ),
      initialCountryCode: 'IN',
      dropdownIconPosition: IconPosition.trailing,
      onChanged: (phone) => setState(() => fullPhoneNumber = phone.completeNumber),
      validator: (value) {
        if (value == null || value.number.isEmpty) return 'Phone number is required.';
        if (value.number.length != 10) return 'Enter a valid 10-digit number.';
        return null;
      },
    );
  }

  Widget _buildWardSelectionField() {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: selectedWard != null ? '$selectedState > $selectedDistrict > $selectedWard' : '',
      ),
      style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis),
      decoration: _getDropdownStyle("Select Your Ward", Icons.maps_home_work_outlined).dropdownSearchDecoration,
      onTap: _showWardSelectionDialog,
      validator: (value) {
        if (selectedWard == null) return 'Please select your ward.';
        return null;
      },
    );
  }

  void _showWardSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) {
          String? dialogSelectedState = selectedState;
          String? dialogSelectedDistrict = selectedDistrict;
          List<String> dialogDistricts = _districts;
          List<String> dialogWards = _wards;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF203A43),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Select Your Location", style: TextStyle(color: Colors.white, fontSize: 20)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownSearch<String>(
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        items: _states,
                        dropdownDecoratorProps: _getDropdownStyle("Select State", Icons.map_outlined),
                        onChanged: (value) async {
                          if(value != null) {
                            setDialogState(() {
                              dialogSelectedState = value;
                              dialogSelectedDistrict = null;
                              dialogDistricts = [];
                              dialogWards = [];
                            });
                            dialogDistricts = await _locationService.getDistricts(value);
                            setDialogState((){});
                          }
                        },
                        selectedItem: dialogSelectedState,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (dialogSelectedState != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: DropdownSearch<String>(
                          popupProps: const PopupProps.menu(showSearchBox: true),
                          items: dialogDistricts,
                          dropdownDecoratorProps: _getDropdownStyle("Select District", Icons.location_city),
                          onChanged: (value) async {
                            if (value != null) {
                              setDialogState(() {
                                dialogSelectedDistrict = value;
                                dialogWards = [];
                              });
                              dialogWards = await _locationService.getWards(dialogSelectedState!, value);
                              setDialogState((){});
                            }
                          },
                          selectedItem: dialogSelectedDistrict,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (dialogSelectedDistrict != null)
                      Expanded(
                        child: dialogWards.isEmpty
                            ? const Center(child: Text("No wards found.", style: TextStyle(color: Colors.white70)))
                            : ListView.builder(
                            controller: controller,
                            itemCount: dialogWards.length,
                            itemBuilder: (context, index){
                              return ListTile(
                                title: Text(dialogWards[index], style: const TextStyle(color: Colors.white)),
                                onTap: (){
                                  setState(() {
                                    selectedState = dialogSelectedState;
                                    selectedDistrict = dialogSelectedDistrict;
                                    selectedWard = dialogWards[index];
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
                            }
                        ),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  DropDownDecoratorProps _getDropdownStyle(String hint, IconData icon) {
    return DropDownDecoratorProps(
      dropdownSearchDecoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.cyanAccent)),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double offset;
  WavePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromRGBO(64, 224, 208, 0.25)..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(i, size.height * 0.8 + 20 * sin(0.02 * i + offset));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final glowPaint = Paint()..color = const Color.fromRGBO(64, 224, 208, 0.1)..style = PaintingStyle.fill;
    final glowPath = Path();
    glowPath.moveTo(0, size.height * 0.82);
    for (double i = 0; i <= size.width; i++) {
      glowPath.lineTo(i, size.height * 0.82 + 25 * sin(0.015 * i + offset + 1));
    }
    glowPath.lineTo(size.width, size.height);
    glowPath.lineTo(0, size.height);
    glowPath.close();
    canvas.drawPath(glowPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}