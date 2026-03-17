import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class ManageWardsScreen extends StatefulWidget {
  const ManageWardsScreen({super.key});

  @override
  State<ManageWardsScreen> createState() => _ManageWardsScreenState();
}

class _ManageWardsScreenState extends State<ManageWardsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showWardDialog({DocumentSnapshot? existingWard}) {
    final bool isEditing = existingWard != null;
    final TextEditingController nameController = TextEditingController(
      text: isEditing ? existingWard['name'] : '',
    );
    final TextEditingController districtController = TextEditingController(
      text: isEditing ? existingWard['district'] : '',
    );
    // ✅ NEW: Controller to force an ID match with existing sensors
    final TextEditingController idController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2A32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'Edit Ward Details' : 'Add New Ward',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView( // Added to prevent overflow with the new field
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ NEW: Custom ID Field (Only show when creating a new ward)
                  if (!isEditing) ...[
                    TextFormField(
                      controller: idController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Custom Ward ID (Optional)', Icons.vpn_key).copyWith(
                        helperText: 'Leave blank to auto-generate. If your existing sensors use "Ward A", type "Ward A" here to link them.',
                        helperStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                        helperMaxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Ward Name (e.g. Ward 12)', Icons.location_city),
                    validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: districtController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('District / Region', Icons.map),
                    validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _saveWard(
                    wardId: isEditing ? existingWard.id : null,
                    name: nameController.text.trim(),
                    district: districtController.text.trim(),
                    customId: idController.text.trim(), // Pass the custom ID
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Create Ward',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.cyan),
      prefixIcon: Icon(icon, color: Colors.cyan),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.cyan, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _saveWard({String? wardId, required String name, required String district, String? customId}) async {
    try {
      final batch = _firestore.batch();

      // ✅ SMART ID ASSIGNMENT
      String targetId;
      if (wardId != null) {
        targetId = wardId; // Editing an existing ward
      } else if (customId != null && customId.isNotEmpty) {
        targetId = customId; // User provided a specific ID to link existing sensors
      } else {
        targetId = _firestore.collection('locations').doc().id; // Auto-generate if left blank
      }

      final docRef = _firestore.collection('locations').doc(targetId);

      batch.set(docRef, {
        'name': name,
        'district': district,
        'updatedAt': FieldValue.serverTimestamp(),
        if (wardId == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // SMART FEATURE: Auto-initialize pricing for new wards
      if (wardId == null) {
        final pricingRef = _firestore.collection('ward_pricing').doc(targetId);
        batch.set(pricingRef, {
          'wardName': name,
          'pricePerLiter': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      Fluttertoast.showToast(msg: "Ward saved successfully!", backgroundColor: Colors.green);
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save: $e", backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Manage Wards & Locations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.cyan,
        icon: const Icon(Icons.add_location_alt, color: Colors.black),
        label: const Text('Add Ward', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () => _showWardDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Removed the .orderBy('createdAt') so older documents that lack this field will still appear.
        stream: _firestore.collection('locations').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final wards = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: wards.length,
            itemBuilder: (context, index) {
              final doc = wards[index];
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;

              return Card(
                color: const Color(0xFF1E303A),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.cyan,
                    child: Icon(Icons.map, color: Colors.black),
                  ),
                  title: Text(data['name'] ?? 'Unnamed Ward',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('District: ${data['district'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
                      Text('ID: ${doc.id}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      if (createdAt != null)
                        Text('Added: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_location_alt, color: Colors.cyanAccent),
                    onPressed: () => _showWardDialog(existingWard: doc),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'No Wards Registered',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to map your first city ward.\nThis is required before assigning supervisors.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}