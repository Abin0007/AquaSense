import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart'; // For success dialog

class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;
  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Future<UserData?> _userDataFuture;
  bool _isUpdating = false; // Loading state

  // --- Use StreamBuilder for real-time status updates ---
  late Stream<DocumentSnapshot> _complaintStream;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
    // --- Initialize Stream ---
    _complaintStream = FirebaseFirestore.instance
        .collection('complaints')
        .doc(widget.complaint.id)
        .snapshots();
  }

  Future<UserData?> _fetchUserData() async {
    // ... (keep existing _fetchUserData logic) ...
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.complaint.userId).get();
      if (doc.exists) {
        return UserData.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error fetching user data for complaint: $e");
    }
    return null;
  }


  Future<void> _updateStatus(String newStatus, Complaint currentComplaintData) async { // Pass current data
    if (_isUpdating) return; // Prevent double taps

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final supervisorId = FirebaseAuth.instance.currentUser?.uid;

    if (supervisorId == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Error: Could not verify supervisor.'), backgroundColor: Colors.red),
      );
      return;
    }


    debugPrint("Proceeding with Firestore update for status: $newStatus");
    if (mounted) setState(() => _isUpdating = true); // Show loading indicator for Firestore write

    try {
      final newStatusUpdate = ComplaintStatusUpdate(
        status: newStatus,
        updatedAt: Timestamp.now(), // Use server timestamp ideally, but client time is ok here
        supervisorImageUrl: null, // Always null now
        updatedBy: supervisorId,
      );

      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(currentComplaintData.id)
          .update({
        'status': newStatus, // Update the main status field
        'statusHistory': FieldValue.arrayUnion([newStatusUpdate.toMap()]) // Add to history
      });

      debugPrint("Firestore update successful.");
      _showSuccessDialog(newStatus); // Show success animation

    } catch (e) {
      debugPrint("Firestore update failed: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false); // Hide loading indicator
    }
  }

  void _showSuccessDialog(String status) {
    if (!mounted) return; // Ensure widget is still mounted
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Status Updated!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Complaint marked as '$status'.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop(); // Close Dialog
              if (navigator.canPop()) { // Check if we can pop the detail screen
                navigator.pop(); // Go back from detail screen
              }
            },
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMap(GeoPoint location) async {
    // ... (keep existing _launchMap logic) ...
    final uri = Uri.parse("https://maps.google.com/?q=${location.latitude},${location.longitude}"); // Correct Map URL
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) { // Check mounted
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open map.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Use StreamBuilder to listen for real-time changes ---
    return StreamBuilder<DocumentSnapshot>(
        stream: _complaintStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold( // Show basic scaffold while waiting
              backgroundColor: const Color(0xFF0F2027),
              appBar: AppBar(title: const Text('Complaint Details'), backgroundColor: const Color(0xFF152D4E)),
              body: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
            );
          }
          if (snapshot.hasError) {
            return Scaffold( // Show error scaffold
              backgroundColor: const Color(0xFF0F2027),
              appBar: AppBar(title: const Text('Complaint Details'), backgroundColor: const Color(0xFF152D4E)),
              body: Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red))),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold( // Show not found scaffold
              backgroundColor: const Color(0xFF0F2027),
              appBar: AppBar(title: const Text('Complaint Details'), backgroundColor: const Color(0xFF152D4E)),
              body: const Center(child: Text("Complaint not found.", style: TextStyle(color: Colors.white70))),
            );
          }

          // Get the latest complaint data from the stream
          final Complaint liveComplaint = Complaint.fromFirestore(snapshot.data!);
          String currentStatus = liveComplaint.status;
          bool isResolved = currentStatus.toLowerCase() == 'resolved'; // Check if resolved
          int? citizenRating = liveComplaint.citizenRating; // Get rating

          // Get supervisor images based on latest data (Still useful for display even if not uploading new ones)
          final String? progressImageUrl = liveComplaint.getSupervisorImageForStatus('In Progress');
          final String? resolvedImageUrl = liveComplaint.getSupervisorImageForStatus('Resolved');


          return Scaffold(
            backgroundColor: const Color(0xFF0F2027),
            appBar: AppBar(
              title: const Text('Complaint Details'),
              backgroundColor: const Color(0xFF152D4E),
            ),
            body: Stack( // Use Stack to overlay loading indicator
                children: [
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // --- Display Images ---
                      if (liveComplaint.imageUrl != null)
                        _buildImageViewer(
                          title: "Citizen's Submitted Image",
                          imageUrl: liveComplaint.imageUrl!,
                        ),
                      if (progressImageUrl != null)
                        _buildImageViewer(
                          title: "Supervisor 'In Progress' Image",
                          imageUrl: progressImageUrl,
                        ),
                      if (resolvedImageUrl != null)
                        _buildImageViewer(
                          title: "Supervisor 'Resolved' Image",
                          imageUrl: resolvedImageUrl,
                        ),
                      // --- End Supervisor Images ---

                      const SizedBox(height: 24),
                      _buildDetailRow('Type:', liveComplaint.type),
                      _buildDetailRow('Description:', liveComplaint.description),
                      _buildDetailRow('Submitted On:', DateFormat('d MMM yyyy, h:mm a').format(liveComplaint.createdAt.toDate())),
                      _buildDetailRow('Current Status:', currentStatus, isStatus: true),

                      // *** NEW: Display Citizen Rating if available ***
                      if (isResolved && citizenRating != null) ...[
                        const Divider(height: 30, color: Colors.white24),
                        _buildCitizenRatingDisplay(citizenRating),
                      ],
                      // *** END: Citizen Rating Display ***

                      const Divider(height: 30, color: Colors.white24),
                      _buildUserData(), // This uses a FutureBuilder, doesn't need stream data
                      if (liveComplaint.location != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: OutlinedButton.icon(
                            onPressed: () => _launchMap(liveComplaint.location!),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text("View Location on Map"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: const BorderSide(color: Colors.cyanAccent),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
                      // --- Pass liveComplaint data to button builder ---
                      if (currentStatus != 'Resolved')
                        _buildStatusButtons(currentStatus, liveComplaint),
                    ],
                  ),
                  // --- Loading Indicator ---
                  if (_isUpdating)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.cyanAccent),
                            SizedBox(height: 16),
                            Text("Updating Status...", style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ]
            ),
          );
        }
    );
  }

  // Helper widget to display images with titles
  Widget _buildImageViewer({required String title, required String imageUrl}) {
    // ... (keep existing _buildImageViewer logic) ...
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
              fit: BoxFit.contain, // Changed fit to contain to prevent distortion
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                // Use a more informative error icon
                return Container(
                    height: 150, // Give it a defined height
                    color: Colors.grey[800],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50))
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUserData() {
    // ... (keep existing _buildUserData logic using FutureBuilder) ...
    return FutureBuilder<UserData?>(
      future: _userDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Text('Could not load user details.', style: TextStyle(color: Colors.redAccent));
        }
        final user = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Submitted By:', user.name),
            _buildDetailRow('Contact:', user.phoneNumber ?? 'Not provided'),
            _buildDetailRow('Ward:', user.wardId.isEmpty ? 'N/A' : user.wardId),
          ],
        );
      },
    );
  }

  // --- MODIFIED: Removed image requirement logic ---
  Widget _buildStatusButtons(String currentStatus, Complaint complaintData) {
    // Enable "In Progress" only if status is "Submitted"
    bool canMarkInProgress = currentStatus == 'Submitted';

    // Enable "Resolved" if status is "Submitted" OR "In Progress"
    bool canMarkResolved = (currentStatus == 'Submitted' || currentStatus == 'In Progress');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Update Status:', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        ElevatedButton(
          // Pass complaintData to _updateStatus
          onPressed: canMarkInProgress ? () => _updateStatus('In Progress', complaintData) : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5)
          ),
          child: const Text('Mark as In Progress'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          // Pass complaintData to _updateStatus
          onPressed: canMarkResolved ? () => _updateStatus('Resolved', complaintData) : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5)
          ),
          child: const Text('Mark as Resolved'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isStatus = false}) {
    // ... (keep existing _buildDetailRow logic) ...
    Color valueColor = Colors.white; // Default color
    if (isStatus) {
      switch (value.toLowerCase()) {
        case 'in progress': valueColor = Colors.orangeAccent; break;
        case 'resolved': valueColor = Colors.greenAccent; break;
        case 'submitted': valueColor = Colors.blueAccent; break;
        default: valueColor = Colors.grey;
      }
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
              color: valueColor, // Use determined color
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // *** NEW: Widget to display the citizen's rating ***
  Widget _buildCitizenRatingDisplay(int rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Citizen Feedback:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) => Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 24,
          )),
        ),
      ],
    );
  }
}