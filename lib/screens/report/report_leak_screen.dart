import 'dart:io';
import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/services/storage_service.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
// Import for debugPrint

class ReportLeakScreen extends StatefulWidget { // <-- Class Definition
  const ReportLeakScreen({super.key});

  @override
  State<ReportLeakScreen> createState() => _ReportLeakScreenState();
}

class _ReportLeakScreenState extends State<ReportLeakScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  final List<String> _allComplaintTypes = ['Leakage', 'Quality', 'No Water', 'Billing', 'Other'];
  final List<String> _limitedComplaintTypes = ['Leakage', 'Other'];
  List<String> _complaintTypes = [];

  String? _selectedComplaintType;
  XFile? _imageFile;
  Position? _currentPosition;
  bool _isLocationLoading = false;
  bool _isSubmitting = false; // <-- New state variable for loading

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _setComplaintTypes();
  }

  Future<void> _setComplaintTypes() async {
    final user = FirebaseAuth.instance.currentUser;
    bool hasConnection = false;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          hasConnection = userDoc.data()?['hasActiveConnection'] ?? false;
        }
      } catch (e) {
        debugPrint("Error fetching user connection status: $e");
        // Assume no connection if there's an error fetching
      }
    }

    if (mounted) {
      setState(() {
        _complaintTypes = hasConnection ? _allComplaintTypes : _limitedComplaintTypes;
        // Ensure selected type is valid if list changes
        if (_selectedComplaintType != null && !_complaintTypes.contains(_selectedComplaintType)) {
          _selectedComplaintType = null;
        }
      });
    }
  }


  @override
  void dispose() {
    _descriptionController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 70); // Added imageQuality
      if (pickedFile != null) {
        // Optional: Check file size
        final file = File(pickedFile.path);
        if (await file.length() > 5 * 1024 * 1024) { // 5MB limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Image size exceeds 5MB limit.'),
              backgroundColor: Colors.orange,
            ));
          }
          return;
        }
        setState(() => _imageFile = pickedFile);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }


  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
        setState(() => _isLocationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.')));
        setState(() => _isLocationLoading = false);
        return;
      }

      // Fetch position only if permission granted
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Medium accuracy is often sufficient
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }


  // --- MODIFIED SUBMISSION LOGIC ---
  Future<void> _submitComplaint() async { // Changed to async
    if (_isSubmitting) return; // Prevent double submission

    if (!_formKey.currentState!.validate()) return;
    if (_selectedComplaintType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a complaint type.')));
      return;
    }

    // --- Show Loading Indicator ---
    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      // 1. Upload image (if exists)
      String? imageUrl;
      if (_imageFile != null) {
        debugPrint("Attempting to upload complaint image...");
        imageUrl = await _storageService.uploadComplaintImage(_imageFile!, user.uid);
        debugPrint("Image uploaded successfully: $imageUrl");
      }

      // 2. Get User's Ward ID
      String userWardId = 'unknown'; // Default value
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        userWardId = userDoc.data()?['wardId'] ?? 'unknown';
      } catch (e) {
        debugPrint("Could not fetch user ward ID, using 'unknown'. Error: $e");
      }


      // 3. Create Complaint Object
      final complaint = Complaint(
        userId: user.uid,
        type: _selectedComplaintType!,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        wardId: userWardId,
        location: _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        createdAt: Timestamp.now(),
        status: 'Submitted', // Initial status
        statusHistory: [ // Add initial status to history
          ComplaintStatusUpdate(
            status: 'Submitted',
            updatedAt: Timestamp.now(),
            updatedBy: user.uid, // User submitted it
          ),
        ],
      );

      // 4. Submit to Firestore
      debugPrint("Attempting to submit complaint to Firestore...");
      await _firestoreService.submitComplaint(complaint);
      debugPrint("Complaint submitted successfully to Firestore.");

      // 5. Show Success Dialog (ONLY if everything succeeded)
      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      // 6. Show Error Message on Failure
      debugPrint("Complaint submission failed: $e");
      // Use captured context
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to submit complaint: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 7. Hide Loading Indicator
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  // --- END MODIFIED SUBMISSION LOGIC ---

  // _performBackgroundSubmission removed as logic is now inside _submitComplaint

  void _showSuccessDialog() {
    // Check if context is still valid before showing dialog
    if (!mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog( // Use dialogContext
          backgroundColor: const Color(0xFF2C5364),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
              const SizedBox(height: 16),
              const Text("Complaint Submitted!",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Your complaint has been successfully submitted.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close Dialog using dialogContext
                // Check mount status *again* before popping the screen context
                if (mounted) {
                  Navigator.of(context).pop(); // Go back from report screen
                }
              },
              child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ));
  }

  // Build method and other helpers remain mostly the same,
  // but the submit button needs to handle the _isSubmitting state.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
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
              _buildDropdown(),
              const SizedBox(height: 20),
              CustomInput(
                controller: _descriptionController,
                hintText: 'Describe the issue...',
                icon: Icons.description_outlined,
                glowAnimation: _glowController,
                maxLines: 4, // Allow more lines for description
                validator: (value) => value!.trim().isEmpty ? 'Description cannot be empty.' : null,
              ),
              const SizedBox(height: 20),
              _buildImagePicker(),
              const SizedBox(height: 20),
              _buildLocationPicker(),
              const SizedBox(height: 30),
              // --- Updated Submit Button ---
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint, // Disable button when submitting
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  disabledBackgroundColor: Colors.grey[600], // Visual feedback when disabled
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
                    : const Text(
                  'Submit Complaint',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // --- End Updated Submit Button ---
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedComplaintType,
      items: _complaintTypes.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(color: Colors.white)), // Ensure text is white
        );
      }).toList(),
      onChanged: (newValue) => setState(() => _selectedComplaintType = newValue),
      // Style the dropdown itself
      dropdownColor: const Color(0xFF203A43), // Background color of the dropdown list
      style: const TextStyle(color: Colors.white), // Style for the selected item display
      iconEnabledColor: Colors.white70, // Color of the dropdown arrow
      decoration: InputDecoration(
        hintText: 'Type of Complaint',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.category_outlined, color: Colors.white70),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.1), // Slightly transparent background
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.3)), // Subtle border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5), // Highlight border on focus
        ),
      ),
      validator: (value) => value == null ? 'Please select a complaint type.' : null,
    );
  }


  Widget _buildImagePicker() {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: _imageFile != null
              ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(_imageFile!.path), fit: BoxFit.contain))
              : const Center(child: Column( // Added icon and text for clarity
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_search, color: Colors.white70, size: 40),
              SizedBox(height: 8),
              Text('No image selected.', style: TextStyle(color: Colors.white70)),
            ],
          )),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.cyanAccent),
              label: const Text('Camera', style: TextStyle(color: Colors.cyanAccent)),
            ),
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, color: Colors.cyanAccent),
              label: const Text('Gallery', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: _currentPosition == null
              ? const Text(
            'No location attached.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          )
              : Text(
            'Location Attached:\nLat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}', // Increased precision
            style: const TextStyle(color: Colors.greenAccent),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        _isLocationLoading
            ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyanAccent))
            : TextButton.icon(
          onPressed: _getCurrentLocation,
          icon: const Icon(Icons.my_location, color: Colors.cyanAccent),
          label: const Text('Attach Current Location', style: TextStyle(color: Colors.cyanAccent)),
        ),
      ],
    );
  }

} // End of _ReportLeakScreenState