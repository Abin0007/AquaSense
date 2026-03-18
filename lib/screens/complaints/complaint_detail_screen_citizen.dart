import 'package:aquasense/models/complaint_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations


class ComplaintDetailScreenCitizen extends StatefulWidget { // Change to StatefulWidget
  final Complaint complaint;
  const ComplaintDetailScreenCitizen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreenCitizen> createState() => _ComplaintDetailScreenCitizenState();
}

class _ComplaintDetailScreenCitizenState extends State<ComplaintDetailScreenCitizen> {

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
      // The StreamBuilder below will automatically rebuild the UI
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use a StreamBuilder to get real-time updates for rating
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('complaints').doc(widget.complaint.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: const Color(0xFF0F2027),
              appBar: AppBar(title: const Text('Complaint Details'), backgroundColor: const Color(0xFF152D4E)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Get the latest complaint data, including rating
          final Complaint currentComplaint = Complaint.fromFirestore(snapshot.data!);
          bool isResolved = currentComplaint.status.toLowerCase() == 'resolved';
          bool alreadyRated = currentComplaint.citizenRating != null;

          // Get supervisor images
          final String? progressImageUrl = currentComplaint.getSupervisorImageForStatus('In Progress');
          final String? resolvedImageUrl = currentComplaint.getSupervisorImageForStatus('Resolved');


          return Scaffold(
            backgroundColor: const Color(0xFF0F2027),
            appBar: AppBar(
              title: const Text('Complaint Details'),
              backgroundColor: const Color(0xFF152D4E),
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // --- Display Images ---
                if (currentComplaint.imageUrl != null)
                  _buildImageViewer(
                    title: "Your Submitted Image",
                    imageUrl: currentComplaint.imageUrl!,
                  ),
                if (progressImageUrl != null)
                  _buildImageViewer(
                    title: "Supervisor 'In Progress' Update",
                    imageUrl: progressImageUrl,
                  ),
                if (resolvedImageUrl != null)
                  _buildImageViewer(
                    title: "Supervisor 'Resolved' Update",
                    imageUrl: resolvedImageUrl,
                  ),
                // --- End Display Images ---

                const SizedBox(height: 24),
                _buildDetailRow('Type:', currentComplaint.type),
                _buildDetailRow('Description:', currentComplaint.description),
                _buildDetailRow('Submitted On:', DateFormat('d MMM yyyy, h:mm a').format(currentComplaint.createdAt.toDate())),
                _buildDetailRow('Current Status:', currentComplaint.status, isStatus: true),

                // --- Rating Section ---
                if (isResolved) ...[
                  const Divider(height: 30, color: Colors.white24),
                  if (!alreadyRated)
                    _buildRatingWidget(currentComplaint.id!)
                  else // Show static stars if already rated
                    _buildStaticRatingDisplay(currentComplaint.citizenRating!),
                ],
                // --- End Rating Section ---
              ].animate(interval: 50.ms).fadeIn(), // Add subtle animation
            ),
          );
        }
    );
  }

  // Helper widget to display images with titles (same as supervisor screen)
  Widget _buildImageViewer({required String title, required String imageUrl}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50));
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRow(String title, String value, {bool isStatus = false}) {
    // ... (keep existing _buildDetailRow logic) ...
    Color statusColor;
    switch (value.toLowerCase()) {
      case 'in progress':
        statusColor = Colors.orangeAccent;
        break;
      case 'resolved':
        statusColor = Colors.greenAccent;
        break;
      default: // Submitted or other
        statusColor = Colors.blueAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isStatus ? statusColor : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: Rating Input Widget ---
  Widget _buildRatingWidget(String complaintId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Rate Supervisor's Service:", style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start, // Align stars left
          children: List.generate(5, (index) {
            return InkWell(
              onTap: () => _submitRating(complaintId, index + 1),
              child: const Padding( // Add padding around stars
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.star_border_outlined, // Use outline
                  color: Colors.amber,
                  size: 36, // Make stars larger for easier tapping
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // --- NEW: Static Rating Display ---
  Widget _buildStaticRatingDisplay(int rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Your Rating:", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (index) => Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 24, // Smaller size for display only
          )),
        ),
      ],
    );
  }
}