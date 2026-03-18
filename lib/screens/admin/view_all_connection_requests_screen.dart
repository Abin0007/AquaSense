import 'package:aquasense/models/connection_request_model.dart';
// Reuse the supervisor's detail screen for managing requests
import 'package:aquasense/screens/supervisor/connection_request_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart'; // Use slide transition
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ViewAllConnectionRequestsScreen extends StatefulWidget {
  const ViewAllConnectionRequestsScreen({super.key});

  @override
  State<ViewAllConnectionRequestsScreen> createState() =>
      _ViewAllConnectionRequestsScreenState();
}

class _ViewAllConnectionRequestsScreenState
    extends State<ViewAllConnectionRequestsScreen> {

  // Function to determine sorting priority for status
  int _getStatusPriority(String status) {
    // Order: Submitted -> Verification -> Scheduled -> Approved -> Rejected -> Completed
    switch (status.toLowerCase()) {
      case 'application submitted': return 0;
      case 'document verification': return 1;
      case 'site visit scheduled': return 2;
      case 'approved': return 3;
      case 'rejected': return 4; // Show rejected before completed
      case 'completed': return 5;
      default: return 6;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('All Connection Requests'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connection_requests')
        // Fetch all requests, order by applied date initially
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No connection requests found in the system.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          var requests = snapshot.data!.docs
              .map((doc) => ConnectionRequest.fromFirestore(doc))
              .toList();

          // Sort primarily by status priority, then by applied date (newest first for same status)
          requests.sort((a, b) {
            final priorityA = _getStatusPriority(a.currentStatus);
            final priorityB = _getStatusPriority(b.currentStatus);
            if (priorityA != priorityB) {
              return priorityA.compareTo(priorityB);
            }
            return b.appliedAt.compareTo(a.appliedAt); // Newest first within the same status
          });


          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              Color statusColor;
              switch (request.currentStatus.toLowerCase()) {
                case 'rejected': statusColor = Colors.redAccent; break;
                case 'completed': statusColor = Colors.greenAccent; break;
                case 'approved': statusColor = Colors.cyanAccent; break;
                case 'site visit scheduled': statusColor = Colors.purpleAccent; break;
                case 'document verification': statusColor = Colors.orangeAccent; break;
                default: statusColor = Colors.blueAccent; // Submitted
              }


              return Card(
                color: Colors.white.withAlpha(20),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.person_pin_circle_outlined, color: Colors.white70), // Added an icon
                  title: Text(request.userName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Ward: ${request.wardId} • Applied: ${DateFormat('d MMM yyyy').format(request.appliedAt.toDate())}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: Text(
                    request.currentStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Slightly smaller status text
                    ),
                  ),
                  onTap: () {
                    // Navigate using SlideFadeRoute
                    Navigator.of(context).push(
                      SlideFadeRoute(
                        page: ConnectionRequestDetailScreen(request: request),
                        // Admin uses the same detail screen as supervisor for management
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: -0.1);
            },
          );
        },
      ),
    );
  }
}