import 'dart:io';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/services/storage_service.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final UserData userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final StorageService _storageService = StorageService();
  bool _isLoading = false;
  XFile? _imageFile;
  String? _newProfileImageUrl;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData.name;
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.white),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      // 1. Upload new profile picture if selected
      if (_imageFile != null) {
        _newProfileImageUrl = await _storageService.uploadProfilePicture(_imageFile!, user.uid);
      }

      // 2. Update Firestore with new name and profile URL
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        if (_newProfileImageUrl != null) 'profileImageUrl': _newProfileImageUrl,
      };
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);

      // 3. Update password if fields are filled
      if (_currentPasswordController.text.isNotEmpty) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text,
          ),
        );
        await user.updatePassword(_newPasswordController.text);
      }

      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ));
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Failed to update profile: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            _buildProfilePictureSection(),
            const SizedBox(height: 30),
            const Text("Personal Information", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(color: Colors.white24, height: 20),
            CustomInput(
              controller: _nameController,
              hintText: "Full Name",
              icon: Icons.person_outline,
              glowAnimation: _glowController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Full Name is required.';
                if (!value.trim().contains(' ')) return 'Please enter both first and last name.';
                if (value.trim().length < 3) return 'Name must be at least 3 characters.';
                return null;
              },
            ),
            const SizedBox(height: 30),
            const Text("Change Password", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(color: Colors.white24, height: 20),
            CustomInput(
              controller: _currentPasswordController,
              hintText: "Current Password",
              icon: Icons.lock_outline,
              isPassword: true,
              glowAnimation: _glowController,
            ),
            const SizedBox(height: 16),
            CustomInput(
              controller: _newPasswordController,
              hintText: "New Password",
              icon: Icons.lock_person_outlined,
              isPassword: true,
              glowAnimation: _glowController,
              validator: (value) {
                if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                  return 'New password is required.';
                }
                if (value != null && value.isNotEmpty && value.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                if (value != null && value.isNotEmpty && !RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$').hasMatch(value)) {
                  return 'Use uppercase, number & symbol.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomInput(
              controller: _confirmPasswordController,
              hintText: "Confirm New Password",
              icon: Icons.lock_reset_outlined,
              isPassword: true,
              glowAnimation: _glowController,
              validator: (value) {
                if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ].animate(interval: 100.ms).fadeIn().slideX(begin: -0.1),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.white.withAlpha(20),
            backgroundImage: _imageFile != null
                ? FileImage(File(_imageFile!.path))
                : NetworkImage(widget.userData.profileImageUrl ?? '') as ImageProvider,
            child: widget.userData.profileImageUrl == null && _imageFile == null
                ? Image.asset('assets/icon/app_icon.png') // Fallback to asset
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent,
                ),
                child: const Icon(Icons.edit, color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}