import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ NEW: Import AuthService to properly handle Google Disconnect
import 'package:aquasense/utils/auth_service.dart';

// --- Import all Admin Modules ---
// Personnel
import 'package:aquasense/screens/admin/personnel/manage_supervisors_screen.dart';
import 'package:aquasense/screens/admin/user_list_screen.dart';
// Finance
import 'package:aquasense/screens/admin/finance/ward_pricing_config_screen.dart';
import 'package:aquasense/screens/admin/finance/admin_cash_settlements_screen.dart';
// Infrastructure
import 'package:aquasense/screens/admin/infrastructure/manage_wards_screen.dart';
import 'package:aquasense/screens/admin/iot/infrastructure_reports_screen.dart';
import 'package:aquasense/screens/admin/iot/global_iot_dashboard_screen.dart';
// Civic
import 'package:aquasense/screens/admin/view_all_complaints_screen.dart';
import 'package:aquasense/screens/admin/view_all_connection_requests_screen.dart';
import 'package:aquasense/screens/admin/manage_announcements_screen.dart';
// Auth
import 'package:aquasense/screens/auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Top-level stats variables
  int _totalUsers = 0;
  int _activeComplaints = 0;
  int _pendingSettlements = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchQuickStats();
  }

  // Efficient count queries to save Firestore reads (No stream leaks here!)
  Future<void> _fetchQuickStats() async {
    try {
      final userCount = await _firestore.collection('users').count().get();
      final complaintsCount = await _firestore.collection('complaints')
          .where('status', isNotEqualTo: 'Resolved').count().get();
      final settlementsCount = await _firestore.collection('cash_collections')
          .where('status', isEqualTo: 'PENDING_SETTLEMENT').count().get();

      if (mounted) {
        setState(() {
          _totalUsers = userCount.count ?? 0;
          _activeComplaints = complaintsCount.count ?? 0;
          _pendingSettlements = settlementsCount.count ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // ✅ FIXED LOGOUT: Now uses AuthService to correctly clear the Google session
  void _logout(BuildContext context) async {
    try {
      await AuthService().logoutUser();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Admin Command Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: () {
              setState(() => _isLoadingStats = true);
              _fetchQuickStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.cyan,
        backgroundColor: const Color(0xFF1A2A32),
        onRefresh: _fetchQuickStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- QUICK STATS ROW ---
              const Text('System Overview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildStatsRow(),
              const SizedBox(height: 24),

              // --- CONTROL MODULES ---
              _buildSectionHeader('Finance & Economy', Icons.account_balance),
              _buildActionTile(
                title: 'Ward Pricing Config',
                subtitle: 'Update water rates per liter',
                icon: Icons.currency_rupee,
                iconColor: Colors.greenAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardPricingConfigScreen())),
              ),
              _buildActionTile(
                title: 'Cash Settlements',
                subtitle: 'Audit physical cash from supervisors',
                icon: Icons.receipt_long,
                iconColor: Colors.orangeAccent,
                badgeCount: _pendingSettlements, // Show badge if pending
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCashSettlementsScreen())),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Infrastructure & IoT', Icons.satellite_alt),

              _buildActionTile(
                title: 'Global Live IoT Dashboard',
                subtitle: 'Real-time tanks and pipeline flow rates',
                icon: Icons.radar,
                iconColor: Colors.greenAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalIoTDashboardScreen())),
              ),

              _buildActionTile(
                title: 'Manage Wards (Locations)',
                subtitle: 'Add or configure city zones',
                icon: Icons.map,
                iconColor: Colors.cyan,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageWardsScreen())),
              ),
              _buildActionTile(
                title: 'IoT Sensor Reports',
                subtitle: 'Global pipeline and tank health',
                icon: Icons.sensors,
                iconColor: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfrastructureReportsScreen())),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Personnel & Users', Icons.people_alt),
              _buildActionTile(
                title: 'Manage Supervisors',
                subtitle: 'Promote citizens and assign wards',
                icon: Icons.admin_panel_settings,
                iconColor: Colors.purpleAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSupervisorsScreen())),
              ),
              _buildActionTile(
                title: 'Global Citizen Directory',
                subtitle: 'View and manage all user accounts',
                icon: Icons.group,
                iconColor: Colors.indigoAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen())),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Civic Engagement', Icons.public),
              _buildActionTile(
                title: 'Global Announcements',
                subtitle: 'Broadcast messages to all citizens',
                icon: Icons.campaign,
                iconColor: Colors.yellowAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAnnouncementsScreen())),
              ),
              _buildActionTile(
                title: 'Master Complaints Log',
                subtitle: 'Oversight of all ward complaints',
                icon: Icons.report_problem,
                iconColor: Colors.redAccent,
                badgeCount: _activeComplaints,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAllComplaintsScreen())),
              ),
              _buildActionTile(
                title: 'Connection Requests',
                subtitle: 'Approve new household pipelines',
                icon: Icons.water_drop,
                iconColor: Colors.lightBlueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAllConnectionRequestsScreen())),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isLoadingStats) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.cyan)));
    }
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Users', _totalUsers.toString(), Icons.group, Colors.purpleAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Active Issues', _activeComplaints.toString(), Icons.warning_amber, Colors.redAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Pending Cash', _pendingSettlements.toString(), Icons.payments, Colors.orangeAccent)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E303A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Card(
      color: const Color(0xFF1A2A32),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        )
            : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        onTap: onTap,
      ),
    );
  }
}