import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/admin/user_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart'; // Import for groupBy

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconForRole(String role) {
    return role == 'supervisor' ? Icons.supervisor_account_outlined : Icons.person_outline;
  }

  Color _getColorForRole(String role) {
    return role == 'supervisor' ? Colors.purpleAccent : _cyanCustom;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashStart,
      appBar: AppBar(
        title: const Text('Personnel Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dashStart, _dashMid, _dashEnd],
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', whereIn: ['citizen', 'supervisor']) // Exclude admins
                    .orderBy('role')
                    .orderBy('wardId')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _cyanCustom));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Database Error', style: TextStyle(color: Colors.red[300])));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No personnel records found.', style: TextStyle(color: Colors.white54)));
                  }

                  // Filter users based on search
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] as String? ?? '').toLowerCase();
                    final email = (data['email'] as String? ?? '').toLowerCase();
                    final wardId = (data['wardId'] as String? ?? '').toLowerCase();
                    final phoneNumber = (data['phoneNumber'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        wardId.contains(_searchQuery) ||
                        phoneNumber.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                    return const Center(child: Text('No users match your search.', style: TextStyle(color: Colors.white54)));
                  }

                  // Grouping Logic
                  final groupedByRole = groupBy<QueryDocumentSnapshot, String>(
                      filteredDocs, (doc) => (doc.data() as Map<String, dynamic>)['role']);

                  final orderedRoles = ['supervisor', 'citizen'];
                  List<Widget> listItems = [];

                  for (var role in orderedRoles) {
                    if (groupedByRole.containsKey(role)) {
                      final usersInRole = groupedByRole[role]!;
                      final groupedByWard = groupBy<QueryDocumentSnapshot, String>(
                          usersInRole, (doc) => (doc.data() as Map<String, dynamic>)['wardId'] ?? 'Unassigned');

                      listItems.add(_buildRoleHeader(role));

                      final sortedWards = groupedByWard.keys.toList()
                        ..sort((a, b) {
                          if (a == 'Unassigned') return 1;
                          if (b == 'Unassigned') return -1;
                          return a.compareTo(b);
                        });

                      for (var wardId in sortedWards) {
                        listItems.add(_buildWardHeader(wardId));
                        listItems.addAll(groupedByWard[wardId]!.map((doc) {
                          final userData = UserData.fromFirestore(doc);
                          return _buildUserTile(userData);
                        }).toList());
                      }
                      listItems.add(const SizedBox(height: 24)); // Space between roles
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 40),
                    children: listItems,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by Name, Ward, or Phone...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _cyanCustom, size: 22),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: _cyanCustom),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
            onPressed: () => _searchController.clear(),
          )
              : null,
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
    );
  }

  Widget _buildRoleHeader(String role) {
    bool isSupervisor = role == 'supervisor';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSupervisor ? Colors.purpleAccent.withValues(alpha: 0.15) : _cyanCustom.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSupervisor ? Colors.purpleAccent.withValues(alpha: 0.3) : _cyanCustom.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSupervisor ? Icons.shield_outlined : Icons.people_outline, color: isSupervisor ? Colors.purpleAccent : _cyanCustom, size: 18),
          const SizedBox(width: 8),
          Text(
            isSupervisor ? 'SYSTEM SUPERVISORS' : 'REGISTERED CITIZENS',
            style: TextStyle(
              color: isSupervisor ? Colors.purpleAccent : _cyanCustom,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildWardHeader(String wardId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.white30, size: 14),
          const SizedBox(width: 8),
          Text(
            wardId == 'Unassigned' ? 'UNASSIGNED PERSONNEL' : 'WARD: ${wardId.toUpperCase()}',
            style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: Colors.white10)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildUserTile(UserData userData) {
    final roleColor = _getColorForRole(userData.role);
    int animationDelay = UniqueKey().hashCode % 10;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Icon(_getIconForRole(userData.role), color: roleColor, size: 20),
        ),
        title: Text(
          userData.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          userData.email,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 12),
        ),
        onTap: () {
          Navigator.of(context).push(SlideFadeRoute(page: UserDetailScreen(userId: userData.uid)));
        },
      ),
    ).animate().fadeIn(delay: (30 * animationDelay).ms).slideX(begin: 0.05);
  }
}