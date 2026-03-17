import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/supervisor/complaint_detail_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);

class ViewAllComplaintsScreen extends StatefulWidget {
  const ViewAllComplaintsScreen({super.key});

  @override
  State<ViewAllComplaintsScreen> createState() => _ViewAllComplaintsScreenState();
}

class _ViewAllComplaintsScreenState extends State<ViewAllComplaintsScreen> {
  // --- Filter State ---
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Resolved'];

  // Sorting priority for status
  int _getStatusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 0; // Highest priority
      case 'in progress':
        return 1;
      case 'resolved':
        return 2;
      default:
        return 3;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.redAccent;
      case 'in progress':
        return Colors.orangeAccent;
      case 'resolved':
        return Colors.greenAccent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashStart,
      appBar: AppBar(
        title: const Text('System Complaints', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
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
            // --- Filter Bar ---
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? _cyanCustom.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? _cyanCustom : Colors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? _cyanCustom : Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeIn().slideY(begin: -0.2),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _cyanCustom));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Database Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No complaints found in the system.', style: TextStyle(color: Colors.white54)));
                  }

                  var complaints = snapshot.data!.docs.map((doc) => Complaint.fromFirestore(doc)).toList();

                  // Apply Filter
                  if (_selectedFilter == 'Active') {
                    complaints = complaints.where((c) => c.status.toLowerCase() != 'resolved').toList();
                  } else if (_selectedFilter == 'Resolved') {
                    complaints = complaints.where((c) => c.status.toLowerCase() == 'resolved').toList();
                  }

                  if (complaints.isEmpty) {
                    return Center(child: Text('No $_selectedFilter complaints found.', style: const TextStyle(color: Colors.white54)));
                  }

                  // Sort by priority
                  complaints.sort((a, b) {
                    final priorityA = _getStatusPriority(a.status);
                    final priorityB = _getStatusPriority(b.status);
                    if (priorityA != priorityB) return priorityA.compareTo(priorityB);
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 40),
                    itemCount: complaints.length,
                    itemBuilder: (context, index) {
                      final complaint = complaints[index];
                      final statusColor = _getStatusColor(complaint.status);

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(SlideFadeRoute(page: ComplaintDetailScreen(complaint: complaint)));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.white30, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "WARD: ${complaint.wardId.toUpperCase()}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      complaint.status.toUpperCase(),
                                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // FIXED: Uses 'complaint.type' from your model
                              Text(
                                complaint.type,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              Text(
                                complaint.description,
                                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy • hh:mm a').format(complaint.createdAt.toDate()),
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: (50 * (index % 10)).ms).slideX(begin: 0.05),
                      );
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
}