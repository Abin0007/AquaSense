import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_list_tile.dart';
import 'package:aquasense/screens/complaints/complaint_detail_screen_citizen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ComplaintStatusScreen extends StatefulWidget { // Changed to StatefulWidget
  const ComplaintStatusScreen({super.key});

  @override
  State<ComplaintStatusScreen> createState() => _ComplaintStatusScreenState();
}

class _ComplaintStatusScreenState extends State<ComplaintStatusScreen> { // Added State
  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return 0;
      case 'in progress': return 1;
      case 'resolved': return 2;
      default: return 3;
    }
  }

  Future<void> _deleteComplaint(BuildContext context, String complaintId) async {
    // ... (keep existing _deleteComplaint logic) ...
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Delete Complaint?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete this complaint?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('complaints').doc(complaintId).delete();
        // Check mounted before showing snackbar
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Complaint deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete complaint: $e')),
        );
      }
    }
  }

  // --- NEW: Function to submit rating ---
  Future<void> _submitRating(String complaintId, int rating) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('complaints').doc(complaintId).update({
        'citizenRating': rating,
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Thank you for your feedback! Rating: $rating stars.'), backgroundColor: Colors.green),
      );
      // No need to call setState here, StreamBuilder will update the UI
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text("You need to be logged in to view your complaints."),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Colors.transparent, // Make AppBar transparent
              foregroundColor: Colors.white, // Ensure back button is visible
              title: Text('My Complaints'),
              pinned: true,
              elevation: 0, // Remove shadow
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('userId', isEqualTo: userId)
                    .snapshots(), // Listen for real-time updates
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: Text('You have not submitted any complaints.', style: TextStyle(color: Colors.white70))));
                  }

                  final complaints = snapshot.data!.docs
                      .map((doc) => Complaint.fromFirestore(doc))
                      .toList();

                  // Sort based on priority and date
                  complaints.sort((a, b) {
                    final priorityA = _getStatusPriority(a.status);
                    final priorityB = _getStatusPriority(b.status);
                    if (priorityA != priorityB) {
                      return priorityA.compareTo(priorityB);
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  return ListView.builder(
                    itemCount: complaints.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final complaint = complaints[index];
                      bool isResolved = complaint.status.toLowerCase() == 'resolved';
                      bool alreadyRated = complaint.citizenRating != null;

                      return Column( // Wrap ListTile and Rating in a Column
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(SlideFadeRoute(
                                // Navigate to citizen detail screen
                                page: ComplaintDetailScreenCitizen(complaint: complaint),
                              ));
                            },
                            child: ComplaintListTile(
                              complaint: complaint,
                              // Pass delete only if not resolved or allow deletion always? (Current: Allow always)
                              onDelete: () => _deleteComplaint(context, complaint.id!),
                              // Pass rating to display it in the tile
                              rating: complaint.citizenRating,
                            ),
                          ),
                          // --- Display Rating Widget Conditionally ---
                          if (isResolved && !alreadyRated)
                            Padding(
                              padding: const EdgeInsets.only(top: 0, bottom: 16.0, left: 16, right: 16), // Adjust padding
                              child: _buildRatingWidget(complaint.id!),
                            ),
                          // You could add an "else if (isResolved && alreadyRated)" here to show static stars
                        ],
                      ).animate()
                          .fadeIn(delay: (50 * index).ms) // Reduced delay
                          .slideX(begin: -0.1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Rating Widget Builder ---
  Widget _buildRatingWidget(String complaintId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Rate the service: ", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(width: 8),
          ...List.generate(5, (index) {
            return InkWell(
              onTap: () => _submitRating(complaintId, index + 1),
              child: const Icon(
                Icons.star_border, // Use border initially
                color: Colors.amber,
                size: 28, // Slightly larger stars
              ),
            );
          }),
        ],
      ),
    );
  }

}