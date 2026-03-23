import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/utils/location_service.dart';
import 'package:aquasense/screens/auth/components/glass_card.dart';
import 'package:aquasense/widgets/otp_input.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  bool isLoading = false;
  String fullPhoneNumber = '';

  final AuthService _authService = AuthService();
  bool isPhoneVerified = false;
  String? _phoneVerificationId;

  final LocationService _locationService = LocationService();

  final List<String> _states = [];
  List<String> _districts = [];
  List<String> _wards = [];

  bool _isDistrictLoading = false;
  bool _isWardLoading = false;

  String? selectedState;
  String? selectedDistrict;
  String? selectedWard;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadStates();
  }

  @override
  void dispose() {
    phoneController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    if (!mounted) return;
    final loadedStates = await _locationService.getStates();
    if (mounted) {
      setState(() => _states.addAll(loadedStates));
    }
  }

  Future<void> _loadDistricts(String state) async {
    if (!mounted) return;
    setState(() => _isDistrictLoading = true);
    final loadedDistricts = await _locationService.getDistricts(state);
    if (mounted) {
      setState(() {
        _districts = loadedDistricts;
        _isDistrictLoading = false;
      });
    }
  }

  Future<void> _loadWards(String state, String district) async {
    if (!mounted) return;
    setState(() => _isWardLoading = true);
    final loadedWards = await _locationService.getWards(state, district);
    if (mounted) {
      setState(() {
        _wards = loadedWards;
        _isWardLoading = false;
      });
    }
  }

  Future<void> _verifyPhoneNumber() async {
    FocusScope.of(context).unfocus();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (fullPhoneNumber.isEmpty || phoneController.text.trim().length < 10) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit phone number.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final isRegistered = await _authService.isPhoneNumberRegistered(fullPhoneNumber.trim());

      if (isRegistered) {
        scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('This phone number is already linked to another account.'),
          backgroundColor: Colors.red,
        ));
        if (mounted) setState(() => isLoading = false);
        return;
      }

      await _authService.sendOtp(
        phoneNumber: fullPhoneNumber,
        // ✅ OTP AUTO-FILL: This callback handles automatic verification on Android.
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          setState(() => isLoading = true);
          try {
            await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
            setState(() {
              isPhoneVerified = true;
              isLoading = false;
            });
            scaffoldMessenger.showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('Phone number auto-verified successfully!')));
          } catch (e) {
            setState(() => isLoading = false);
            scaffoldMessenger.showSnackBar(SnackBar(content: Text("Auto-verification failed: ${e.toString()}")));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => isLoading = false);
          _phoneVerificationId = verificationId;
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          if (_phoneVerificationId == null) {
            setState(() => isLoading = false);
            _phoneVerificationId = verificationId;
            _showOtpDialog();
          }
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => isLoading = false);
          scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.message ?? 'Phone verification failed.')));
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ));
      }
    }
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
          // ✅ UI OVERFLOW FIX: Wrapped content in a scrollable view.
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("Enter the 6-digit code sent to your phone.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Row(
                children: List.generate(
                  6,
                  (index) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OtpInput(
                        controller: otpControllers[index],
                        autoFocus: index == 0,
                        height: 58,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: () async {
                try {
                  final otp = otpControllers.map((e) => e.text).join();
                  if (otp.length == 6 && _phoneVerificationId != null) {
                    await _authService.verifyOtpAndLink(verificationId: _phoneVerificationId!, otp: otp);
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
      },
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'phoneNumber': fullPhoneNumber,
          'wardId': selectedWard!,
          'isPhoneVerified': true,
        });

        await FirebaseFirestore.instance.collection('phoneNumbers').doc(fullPhoneNumber).set({
          'uid': user.uid,
        });
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to update profile: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canContinue = isPhoneVerified && selectedWard != null;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _authService.logoutUser();
            },
          ),
        ],
      ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Welcome, ${user?.displayName ?? 'User'}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 16),
                      const Text("Just a few more details to get you set up.", style: TextStyle(fontSize: 16, color: Colors.white70)),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: IntlPhoneField(
                              controller: phoneController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _getDropdownStyle("Phone Number", Icons.phone_outlined).dropdownSearchDecoration?.copyWith(counterText: '') ?? const InputDecoration(),
                              initialCountryCode: 'IN',
                              onChanged: (phone) {
                                setState(() {
                                  fullPhoneNumber = phone.completeNumber;
                                });
                              },
                            ),
                          ),
                          if (isPhoneVerified)
                            const Padding(
                                padding: EdgeInsets.only(top: 14.0, left: 8.0),
                                child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 30))
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                                  ),
                                  child: const Text("Get OTP"),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildWardDropdowns(),
                      const SizedBox(height: 24),
                      isLoading
                          ? const CircularProgressIndicator(color: Colors.cyanAccent)
                          : ElevatedButton(
                        onPressed: canContinue ? _updateProfile : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: canContinue ? Colors.cyanAccent : Colors.grey[700],
                          foregroundColor: canContinue ? Colors.black : Colors.grey[400],
                        ),
                        child: const Text("Save & Continue", style: TextStyle(fontSize: 18)),
                      ),
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

  Widget _buildWardDropdowns() {
    return Column(
      children: [
        DropdownSearch<String>(
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "Search State",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            menuProps: MenuProps(borderRadius: BorderRadius.circular(20)),
          ),
          items: _states,
          enabled: _states.isNotEmpty,
          dropdownDecoratorProps: _getDropdownStyle(
            _states.isEmpty ? "Loading States..." : "Select State",
            Icons.map_outlined,
          ),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedState = value;
                selectedDistrict = null;
                _districts = [];
                selectedWard = null;
                _wards = [];
              });
              _loadDistricts(value);
            }
          },
          selectedItem: selectedState,
        ),
        if (selectedState != null) ...[
          const SizedBox(height: 16),
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: _districts,
            enabled: !_isDistrictLoading,
            dropdownDecoratorProps: _getDropdownStyle(
              _isDistrictLoading ? "Loading Districts..." : "Select District",
              Icons.location_city,
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedDistrict = value;
                  selectedWard = null;
                  _wards = [];
                });
                _loadWards(selectedState!, value);
              }
            },
            selectedItem: selectedDistrict,
          ),
        ],
        if (selectedDistrict != null) ...[
          const SizedBox(height: 16),
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(showSearchBox: true),
            items: _wards,
            enabled: !_isWardLoading,
            dropdownDecoratorProps: _getDropdownStyle(
              _isWardLoading ? "Loading Wards..." : "Select Ward",
              Icons.maps_home_work_outlined,
            ),
            onChanged: (value) => setState(() => selectedWard = value),
            selectedItem: selectedWard,
          ),
        ],
      ],
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
    final paint = Paint()
      ..color = const Color.fromRGBO(64, 224, 208, 0.25)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.8);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(i, size.height * 0.8 + 20 * sin(0.02 * i + offset));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..color = const Color.fromRGBO(64, 224, 208, 0.1)
      ..style = PaintingStyle.fill;
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