import 'package:aquasense/main.dart'; // For AuthWrapper
import 'package:aquasense/screens/admin/manage_announcements_screen.dart';
import 'package:aquasense/screens/admin/user_list_screen.dart';
import 'package:aquasense/screens/admin/view_all_complaints_screen.dart';
import 'package:aquasense/screens/admin/view_all_connection_requests_screen.dart'; // Import the new screen
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// --- NEW IOT IMPORT ---
import 'package:aquasense/screens/admin/iot/infrastructure_reports_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int? _userCount;
  int? _complaintCount;
  int? _connectionRequestCount;

  @override
  void initState() {
    super.initState();
    _subscribeToCounts();
  }

  // --- NEW: Subscribe to collection counts ---
  void _subscribeToCounts() {
    // User Count
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _userCount = snapshot.size);
      }
    }, onError: (error) {
      debugPrint("Error fetching user count: $error");
      if (mounted) setState(() => _userCount = 0); // Show 0 on error
    });

    // Complaint Count
    FirebaseFirestore.instance
        .collection('complaints')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _complaintCount = snapshot.size);
      }
    }, onError: (error) {
      debugPrint("Error fetching complaint count: $error");
      if (mounted) setState(() => _complaintCount = 0);
    });

    // Connection Request Count (Optional, but useful)
    FirebaseFirestore.instance
        .collection('connection_requests')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _connectionRequestCount = snapshot.size);
      }
    }, onError: (error) {
      debugPrint("Error fetching connection request count: $error");
      if (mounted) setState(() => _connectionRequestCount = 0);
    });
  }

  // Helper function to build STATISTIC cards
  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required int? count, // Make count nullable
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16), // Add padding inside
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(40), color.withAlpha(80)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // Center text
          children: [
            Icon(icon, size: 36, color: color), // Slightly smaller icon
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70, // Subdued title color
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            // Show count or loading indicator
            count == null
                ? const SizedBox(
              height: 28, // Height matching text style
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build ACTION cards (like Manage Announcements)
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(40), color.withAlpha(80)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context); // Capture navigator first
    final authService = AuthService();
    await authService.logoutUser();
    // Ensure the widget is still mounted before navigating
    if (context.mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF152D4E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // Number of columns
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            // --- Stat Cards ---
            _buildStatCard(
              title: 'Total Users',
              icon: Icons.people_alt_outlined,
              color: Colors.lightBlueAccent,
              count: _userCount,
              onTap: () {
                Navigator.of(context).push(
                    SlideFadeRoute(page: const UserListScreen())
                );
              },
            ),
            _buildStatCard(
              title: 'Total Complaints',
              icon: Icons.report_problem_outlined,
              color: Colors.orangeAccent,
              count: _complaintCount,
              onTap: () {
                Navigator.of(context).push(
                    SlideFadeRoute(page: const ViewAllComplaintsScreen())
                );
              },
            ),
            _buildStatCard(
              title: 'Connection Requests',
              icon: Icons.person_add_alt_1_outlined,
              color: Colors.greenAccent,
              count: _connectionRequestCount,
              onTap: () {
                // --- UPDATED NAVIGATION ---
                Navigator.of(context).push(
                    SlideFadeRoute(page: const ViewAllConnectionRequestsScreen())
                );
                // --------------------------
              },
            ),

            // --- Action Cards ---
            _buildActionCard(
              title: 'Manage Announcements',
              icon: Icons.campaign_outlined,
              color: Colors.cyanAccent,
              onTap: () {
                Navigator.of(context).push(
                    SlideFadeRoute(page: const ManageAnnouncementsScreen())
                );
              },
            ),

            // --- NEW: Infrastructure Reports Card ---
            _buildActionCard(
              title: 'Infrastructure Reports',
              icon: Icons.analytics_outlined,
              color: Colors.amberAccent,
              onTap: () {
                Navigator.of(context).push(
                    SlideFadeRoute(page: const InfrastructureReportsScreen())
                );
              },
            ),

          ].animate(interval: 100.ms).fadeIn().scale(delay: 100.ms),
        ),
      ),
    );
  }
}