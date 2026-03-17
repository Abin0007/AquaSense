import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ManageSupervisorsScreen extends StatefulWidget {
  const ManageSupervisorsScreen({super.key});

  @override
  State<ManageSupervisorsScreen> createState() => _ManageSupervisorsScreenState();
}

class _ManageSupervisorsScreenState extends State<ManageSupervisorsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for Ward Names to avoid repeated lookups
  final Map<String, String> _wardNameCache = {};

  Future<String> _getWardName(String wardId) async {
    if (wardId.isEmpty) return 'Unassigned';
    if (_wardNameCache.containsKey(wardId)) return _wardNameCache[wardId]!;

    try {
      final doc = await _firestore.collection('locations').doc(wardId).get();
      if (doc.exists) {
        final name = doc.data()?['name'] ?? 'Unknown Ward';
        _wardNameCache[wardId] = name;
        return name;
      }
      return 'Unknown Ward';
    } catch (e) {
      return 'Error fetching ward';
    }
  }

  void _showAssignSupervisorDialog() {
    final TextEditingController searchController = TextEditingController();
    Map<String, dynamic>? foundUser;
    String? foundUserId;
    String? selectedWardId;
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2A32),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Promote Citizen to Supervisor',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // 1. Search for User
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Citizen Email Address',
                              labelStyle: const TextStyle(color: Colors.cyan),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.cyan),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.cyanAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.cyan),
                          icon: isSearching
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.search, color: Colors.black),
                          onPressed: () async {
                            if (searchController.text.trim().isEmpty) return;
                            setModalState(() => isSearching = true);

                            try {
                              final query = await _firestore.collection('users')
                                  .where('email', isEqualTo: searchController.text.trim())
                                  .limit(1).get();

                              if (query.docs.isNotEmpty) {
                                setModalState(() {
                                  foundUser = query.docs.first.data();
                                  foundUserId = query.docs.first.id;
                                });
                              } else {
                                Fluttertoast.showToast(msg: "User not found", backgroundColor: Colors.red);
                                setModalState(() => foundUser = null);
                              }
                            } finally {
                              setModalState(() => isSearching = false);
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. Show User & Select Ward (If Found)
                    if (foundUser != null) ...[
                      Card(
                        color: const Color(0xFF0F2027),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.purpleAccent, child: Icon(Icons.person, color: Colors.white)),
                          title: Text(foundUser!['name'] ?? 'No Name', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('Current Role: ${foundUser!['role']}', style: const TextStyle(color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Assign to Ward:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),

                      // Fetch Wards for Dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('locations').orderBy('name').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final wards = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF1E303A),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            value: selectedWardId,
                            hint: const Text('Select a Ward', style: TextStyle(color: Colors.white54)),
                            items: wards.map((doc) {
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(doc['name']),
                              );
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedWardId = val),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Promotion
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: selectedWardId == null ? null : () => _promoteUser(foundUserId!, selectedWardId!),
                          child: const Text('Confirm Promotion to Supervisor',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Future<void> _promoteUser(String userId, String wardId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': 'supervisor',
        'wardId': wardId,
      });
      Fluttertoast.showToast(msg: "User promoted to Supervisor!", backgroundColor: Colors.green);
      if (mounted) Navigator.pop(context); // Close bottom sheet
    } catch (e) {
      Fluttertoast.showToast(msg: "Error promoting user: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _revokeSupervisor(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A32),
        title: const Text('Revoke Access?', style: TextStyle(color: Colors.redAccent)),
        content: Text('Are you sure you want to demote $name back to a regular citizen?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'role': 'citizen',
          'wardId': '', // Clear their assigned ward
        });
        Fluttertoast.showToast(msg: "Supervisor access revoked.", backgroundColor: Colors.orange);
      } catch (e) {
        Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Personnel Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF152D4E),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.person_add, color: Colors.black),
        label: const Text('Assign Supervisor', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: _showAssignSupervisorDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Only fetch users who are currently supervisors
        stream: _firestore.collection('users').where('role', isEqualTo: 'supervisor').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No active supervisors found.\nTap below to promote a citizen.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          final supervisors = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: supervisors.length,
            itemBuilder: (context, index) {
              final doc = supervisors[index];
              final data = doc.data() as Map<String, dynamic>;
              final wardId = data['wardId'] ?? '';

              return Card(
                color: const Color(0xFF1E303A),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purpleAccent,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  title: Text(data['name'] ?? 'Unknown User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email'] ?? '', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      FutureBuilder<String>(
                        future: _getWardName(wardId),
                        builder: (context, wardSnap) {
                          return Text(
                            'Assigned to: ${wardSnap.data ?? 'Loading...'}',
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    tooltip: 'Revoke Access',
                    onPressed: () => _revokeSupervisor(doc.id, data['name'] ?? 'User'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}