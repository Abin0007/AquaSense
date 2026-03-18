import 'dart:io';

import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';

class ApplyConnectionScreen extends StatefulWidget {
  const ApplyConnectionScreen({super.key});

  @override
  State<ApplyConnectionScreen> createState() => _ApplyConnectionScreenState();
}

class _ApplyConnectionScreenState extends State<ApplyConnectionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _locationController = TextEditingController();
  File? _pickedFile;
  String? _pickedFileName;
  bool _isLoading = false;

  // Store the position separately to ensure null safety
  Position? _currentPosition;

  late AnimationController _glowController;
  late AnimationController _buttonController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pincodeController.dispose();
    _locationController.dispose();
    _glowController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _locationController.text = 'Fetching location...';
      _isLoading = true;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() {
            _locationController.text = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
        );
        setState(() {
          _locationController.text = 'Location permission permanently denied.';
        });
        return;
      }

      final position = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _locationController.text =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        });
      }

    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
      setState(() {
        _locationController.text = 'Error fetching location.';
      });
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (file.lengthSync() > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('File size exceeds the 5MB limit.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
      setState(() {
        _pickedFile = file;
        _pickedFileName = result.files.single.name;
      });
    }
  }

  void _submitApplication() {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please upload your residential proof document.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please provide a valid current location.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // This is now safe because we check _currentPosition directly
    _showSuccessDialog();
    _performBackgroundSubmission();
  }

  Future<void> _performBackgroundSubmission() async {
    final user = FirebaseAuth.instance.currentUser;
    final position = _currentPosition; // Use the stored position

    if (user == null || position == null) {
      debugPrint("Submission failed: User or position is null.");
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userWardId = userDoc.data()?['wardId'];

      if (userWardId == null) {
        throw Exception("Could not find user's ward. Please complete your profile.");
      }

      final storageService = StorageService();
      final proofUrl = await storageService.uploadResidentialProof(_pickedFile!, user.uid);

      final initialStatus = StatusUpdate(
        status: 'Application Submitted',
        description: 'Your application has been received and is pending verification.',
        updatedAt: Timestamp.now(),
      );

      await FirebaseFirestore.instance.collection('connection_requests').add({
        'userId': user.uid,
        'userName': user.displayName,
        'userEmail': user.email,
        'address': _addressController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'latitude': position.latitude, // Now safe to access
        'longitude': position.longitude, // Now safe to access
        'residentialProofUrl': proofUrl,
        'appliedAt': FieldValue.serverTimestamp(),
        'currentStatus': initialStatus.status,
        'statusHistory': [initialStatus.toMap()],
        'rejectionReason': null,
        'finalConnectionImageUrl': null,
        'connectionCreatedAt': null,
        'wardId': userWardId,
      });
      debugPrint("Background connection request submission successful.");
    } catch (e) {
      debugPrint("Background submission failed: $e");
      // Optionally, show an error to the user here
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
            Lottie.asset('assets/animations/success_checkmark.json',
                repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Application Submitted!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                "Your request for a new connection has been received. You can track its status from the home screen.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child:
            const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for New Connection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              CustomInput(
                controller: _addressController,
                hintText: 'Full Residential Address',
                icon: Icons.home_work_outlined,
                glowAnimation: _glowController,
                validator: (value) =>
                value!.trim().isEmpty ? 'Address cannot be empty.' : null,
              ),
              const SizedBox(height: 20),
              CustomInput(
                controller: _pincodeController,
                hintText: 'Pincode',
                icon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                glowAnimation: _glowController,
                validator: (value) {
                  if (value!.trim().isEmpty) return 'Pincode cannot be empty.';
                  if (value.length != 6) {
                    return 'Please enter a valid 6-digit pincode.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomInput(
                controller: _locationController,
                hintText: 'Location (Latitude, Longitude)',
                icon: Icons.location_on_outlined,
                readOnly: true,
                glowAnimation: _glowController,
                onTap: _getCurrentLocation,
                validator: (value) {
                  if (value!.trim().isEmpty || value.contains('Location') || value.contains('Error')) {
                    return 'Please provide a valid current location.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _buildDocumentPicker(),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent))
                  : _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPicker() {
    final bool isPdf = _pickedFileName?.toLowerCase().endsWith('.pdf') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Residential Proof',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDocument,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(51)),
            ),
            child: _pickedFile != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: isPdf
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _pickedFileName!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
                  : Image.file(
                _pickedFile!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            )
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_outlined,
                    color: Colors.white70, size: 40),
                SizedBox(height: 12),
                Text('Tap to select a document',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Accepted documents: Aadhaar Card, Ration Card, Voter ID, etc.\nFile must be a PDF or Image (JPG, PNG). Max size: 5MB.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTapDown: (_) => _buttonController.forward(),
      onTapUp: (_) {
        _buttonController.reverse();
        _submitApplication();
      },
      onTapCancel: () => _buttonController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(
          CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.cyanAccent,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(100, 255, 218, 0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              "Submit Application",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}