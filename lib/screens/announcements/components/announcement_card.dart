import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool showCreator; // Flag to show creator info
  final bool isSupervisorPost; // Flag if posted by supervisor
  final VoidCallback? onDelete; // Optional delete callback

  const AnnouncementCard({
    super.key,
    required this.doc,
    this.showCreator = false, // Default to false
    this.isSupervisorPost = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? {}; // Null safety
    final String title = data['title'] ?? 'No Title';
    final String message = data['message'] ?? 'No content available.';
    final Timestamp timestamp = data['createdAt'] ?? Timestamp.now();
    final String formattedDate = DateFormat('d MMMM, yyyy, h:mm a').format(timestamp.toDate()); // Added time
    final String? wardId = data['wardId'];
    final bool isSupplyAlert = data['isSupplyAlert'] ?? false;

    // Determine creator text
    String creatorText = '';
    if (showCreator) {
      // More robust check could involve fetching user role based on createdBy, but this is simpler
      creatorText = isSupervisorPost ? ' (Ward Supervisor)' : ' (Admin)';
    }
    if (isSupplyAlert){
      creatorText = ' (Supply Alert)'; // Override if it's a supply alert
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Adjusted padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSupplyAlert
              ? [Colors.blue.withAlpha(40), Colors.cyan.withAlpha(25)] // Different color for alerts
              : [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSupplyAlert ? Colors.cyanAccent.withAlpha(70) : Colors.white.withAlpha(51)),
      ),
      child: Stack( // Use Stack for delete button positioning
        clipBehavior: Clip.none, // Allow button to overflow slightly
        children: [
          Padding( // Add padding to main content so button doesn't overlap text badly
            padding: EdgeInsets.only(right: onDelete != null ? 30 : 0), // Add right padding only if delete is possible
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row( // Row for title and potential Ward ID
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (wardId != null && wardId != 'global') // Show Ward ID if applicable
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Ward: $wardId',
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row( // Row for date and creator
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: isSupplyAlert ? Colors.yellowAccent : Colors.cyanAccent,
                        fontSize: 12,
                      ),
                    ),
                    if(creatorText.isNotEmpty)
                      Padding( // Add padding for spacing
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          creatorText,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontStyle: FontStyle.italic
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20), // Adjusted height
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          // Conditionally display delete button if callback is provided
          if (onDelete != null)
            Positioned(
              top: -12, // Adjust positioning
              right: -12,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20), // Changed icon, smaller size
                onPressed: onDelete,
                tooltip: 'Delete Announcement',
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5), // Slightly darker background
                    padding: const EdgeInsets.all(4) // Smaller padding
                ),
              ),
            ),
        ],
      ),
    );
  }
}