import 'package:aquasense/main.dart';
import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/connections/connection_status_detail_screen.dart';
import 'package:aquasense/screens/profile/about_screen.dart';
import 'package:aquasense/screens/profile/components/profile_menu_item.dart';
import 'package:aquasense/screens/profile/contact_screen.dart';
import 'package:aquasense/screens/profile/edit_profile_screen.dart';
import 'package:aquasense/screens/profile/my_qr_code_screen.dart';
// REMOVED: import 'package:aquasense/screens/profile/notification_settings_screen.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  late Stream<DocumentSnapshot> _userDataStream;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _userDataStream = _fetchUserDataStream();
  }

  Stream<DocumentSnapshot> _fetchUserDataStream() {
    if (currentUser == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots();
  }

  Stream<ConnectionRequest?> getConnectionRequestStream() {
    if (currentUser == null) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('connection_requests')
        .where('userId', isEqualTo: currentUser!.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return ConnectionRequest.fromFirestore(snapshot.docs.first);
    });
  }


  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await _authService.logoutUser();
      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Could not load profile.", style: TextStyle(color: Colors.white70)));
          }

          final userData = UserData.fromFirestore(snapshot.data!);

          // *** MODIFICATION START: Removed interval animation wrapper ***
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProfileHeader(userData).animate().fadeIn().slideX(begin: -0.1), // Animate header individually
              const SizedBox(height: 30),
              _buildInfoCard(userData).animate().fadeIn().slideX(begin: -0.1), // Animate info card individually
              const SizedBox(height: 30),
              _buildSectionTitle("Account").animate().fadeIn().slideX(begin: -0.1), // Animate section individually
              ProfileMenuItem(
                title: 'Edit Profile',
                icon: Icons.person_outline,
                onTap: () {
                  Navigator.of(context).push(
                    SlideFadeRoute(page: EditProfileScreen(userData: userData)),
                  );
                },
              ).animate().fadeIn().slideX(begin: -0.1), // Animate item individually
              const SizedBox(height: 16),
              StreamBuilder<ConnectionRequest?>(
                stream: getConnectionRequestStream(),
                builder: (context, requestSnapshot) {
                  if (userData.hasActiveConnection || (requestSnapshot.hasData && requestSnapshot.data != null)) {
                    return ProfileMenuItem(
                      title: 'My Connection',
                      icon: Icons.plumbing_outlined, // CORRECTED ICON
                      onTap: () {
                        if (requestSnapshot.hasData && requestSnapshot.data != null) {
                          Navigator.of(context).push(SlideFadeRoute(
                            page: ConnectionStatusDetailScreen(request: requestSnapshot.data!),
                          ));
                        }
                      },
                    ).animate().fadeIn().slideX(begin: -0.1); // Animate item individually
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (userData.hasActiveConnection) ...[
                const SizedBox(height: 16),
                ProfileMenuItem(
                  title: 'My Meter QR Code',
                  icon: Icons.qr_code_2,
                  onTap: () {
                    Navigator.of(context).push(
                      SlideFadeRoute(page: const MyQrCodeScreen()),
                    );
                  },
                ).animate().fadeIn().slideX(begin: -0.1), // Animate item individually
              ],
              // *** REMOVED "Settings & Information" Section Start ***
              // const SizedBox(height: 30),
              // _buildSectionTitle("Settings & Information"),
              // ProfileMenuItem(
              //   title: 'Notifications',
              //   icon: Icons.notifications_outlined,
              //   onTap: () {
              //     Navigator.of(context).push(
              //       SlideFadeRoute(page: const NotificationSettingsScreen()),
              //     );
              //   },
              // ),
              // *** REMOVED "Settings & Information" Section End ***
              const SizedBox(height: 30),
              _buildSectionTitle("Help & Support").animate().fadeIn().slideX(begin: -0.1), // Animate section individually
              ProfileMenuItem(
                title: 'Contact Us',
                icon: Icons.support_agent_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    SlideFadeRoute(page: const ContactScreen()),
                  );
                },
              ).animate().fadeIn().slideX(begin: -0.1), // Animate item individually
              const SizedBox(height: 16),
              ProfileMenuItem(
                title: 'About AquaSense',
                icon: Icons.info_outline,
                onTap: () {
                  Navigator.of(context).push(
                    SlideFadeRoute(page: const AboutScreen()),
                  );
                },
              ).animate().fadeIn().slideX(begin: -0.1), // Animate item individually
              const SizedBox(height: 30),
              _buildSectionTitle("Danger Zone").animate().fadeIn().slideX(begin: -0.1), // Animate section individually
              ProfileMenuItem(
                title: 'Logout',
                icon: Icons.logout,
                onTap: _logout,
                isDestructive: true,
              ).animate().fadeIn().slideX(begin: -0.1), // Animate item individually
            ],
            // *** MODIFICATION END: Removed interval animation wrapper ***
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserData userData) {
    final statusColor = userData.hasActiveConnection ? Colors.greenAccent : Colors.orangeAccent;
    ImageProvider backgroundImage;
    if (userData.profileImageUrl != null && userData.profileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(userData.profileImageUrl!);
    } else {
      backgroundImage = const AssetImage('assets/icon/app_icon.png');
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 3),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF2C5364),
            backgroundImage: backgroundImage,
            // Handle potential errors loading network image
            onBackgroundImageError: (_, __) {},
            child: backgroundImage is AssetImage || userData.profileImageUrl == null || userData.profileImageUrl!.isEmpty
                ? const Icon(Icons.person, size: 50, color: Colors.white70) // Placeholder Icon
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userData.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userData.email,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(UserData userData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem("Ward ID", userData.wardId.isEmpty ? 'N/A' : userData.wardId), // Show N/A if wardId is empty
              _buildInfoItem("Status", userData.hasActiveConnection ? "Active" : "Inactive",
                  valueColor: userData.hasActiveConnection ? Colors.greenAccent : Colors.orangeAccent),
              _buildInfoItem("Member Since", DateFormat('MMM yyyy').format(userData.createdAt.toDate())),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildInfoItem("Phone Number", userData.phoneNumber ?? 'Not Provided'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}