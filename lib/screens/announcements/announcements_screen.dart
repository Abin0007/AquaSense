import 'package:aquasense/models/user_data.dart'; // Import UserData
import 'package:aquasense/screens/announcements/components/announcement_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnnouncementsScreen extends StatefulWidget {
  final UserData userData; // Receive user data

  const AnnouncementsScreen({super.key, required this.userData});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {

  @override
  void initState() {
    super.initState();
    _markAnnouncementsAsRead(); // Mark as read when screen opens
  }

  // --- Function to update the last read timestamp ---
  Future<void> _markAnnouncementsAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        // --- FIX: Declare latestTimestamp here ---
        Timestamp? latestTimestamp;
        // ----------------------------------------

        // Find the latest announcement timestamp relevant to this user
        Query query = FirebaseFirestore.instance.collection('announcements');

        // Apply filtering logic similar to build() to find the latest *relevant* timestamp
        if (widget.userData.role != 'admin' && widget.userData.wardId.isNotEmpty) {
          // Fetch the latest global and latest ward announcement separately and compare timestamps.
          final globalQuery = FirebaseFirestore.instance.collection('announcements')
              .where('wardId', isEqualTo: null)
              .orderBy('createdAt', descending: true).limit(1);
          final wardQuery = FirebaseFirestore.instance.collection('announcements')
              .where('wardId', isEqualTo: widget.userData.wardId)
              .orderBy('createdAt', descending: true).limit(1);

          final results = await Future.wait([globalQuery.get(), wardQuery.get()]);
          Timestamp? latestGlobalTs;
          Timestamp? latestWardTs;

          if (results[0].docs.isNotEmpty) {
            latestGlobalTs = (results[0].docs.first.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
          }
          if (results[1].docs.isNotEmpty) {
            latestWardTs = (results[1].docs.first.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
          }

          // Determine the most recent timestamp between global and ward-specific
          if (latestGlobalTs != null && latestWardTs != null) {
            latestTimestamp = latestGlobalTs.compareTo(latestWardTs) > 0 ? latestGlobalTs : latestWardTs;
          } else {
            latestTimestamp = latestGlobalTs ?? latestWardTs;
          }

        } else if (widget.userData.role != 'admin' && widget.userData.wardId.isEmpty) {
          // User has no ward ID - only check global
          query = query.where('wardId', isEqualTo: null).orderBy('createdAt', descending: true).limit(1);
          final snapshot = await query.get();
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data() as Map<String, dynamic>?;
            latestTimestamp = data?['createdAt'] as Timestamp?;
          }
        } else { // Admin
          // Admin - check the absolute latest
          query = query.orderBy('createdAt', descending: true).limit(1);
          final snapshot = await query.get();
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data() as Map<String, dynamic>?;
            latestTimestamp = data?['createdAt'] as Timestamp?;
          }
        }

        // Only update if there was an announcement to read
        if (latestTimestamp != null) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            // Set timestamp slightly ahead to avoid race conditions with stream
            'lastReadAnnouncementsTimestamp': Timestamp(latestTimestamp.seconds + 1, 0),
          });
          debugPrint("Updated lastReadAnnouncementsTimestamp for user $userId to ${latestTimestamp.toDate().add(const Duration(seconds: 1))}");
        } else {
          // If no announcements ever, set it to now so indicator doesn't show for empty list
          // Check if timestamp already exists before overwriting
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final userDataMap = userDoc.data();
          if (userDataMap != null && !userDataMap.containsKey('lastReadAnnouncementsTimestamp')) {
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'lastReadAnnouncementsTimestamp': Timestamp.now(),
            });
            debugPrint("Set initial lastReadAnnouncementsTimestamp for user $userId");
          }
        }


      } catch (e) {
        debugPrint("Error updating lastReadAnnouncementsTimestamp: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // --- *** REVERTED QUERY LOGIC & ADDED CLIENT-SIDE FILTERING *** ---
    Query query = FirebaseFirestore.instance.collection('announcements');

    // Fetch all announcements ordered by date. Filtering will happen client-side for non-admins.
    query = query.orderBy('createdAt', descending: true);
    // --- *** END OF REVERTED LOGIC *** ---


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
              backgroundColor: Colors.transparent,
              expandedHeight: 120.0,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold)),
                centerTitle: true, // Center title
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(), // Use the broader query
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Something went wrong: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))); // Show error
                  }

                  // Start with all fetched announcements
                  List<QueryDocumentSnapshot> allAnnouncements = snapshot.data?.docs ?? [];

                  // --- Client-side filtering if not admin ---
                  List<QueryDocumentSnapshot> relevantAnnouncements;
                  if (widget.userData.role != 'admin' && widget.userData.wardId.isNotEmpty) {
                    relevantAnnouncements = allAnnouncements.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final wardId = data['wardId'] as String?;
                      // Keep if wardId is null (global) OR matches user's ward
                      return wardId == null || wardId == widget.userData.wardId;
                    }).toList();
                  } else if (widget.userData.role != 'admin') { // Non-admin, no wardId
                    relevantAnnouncements = allAnnouncements.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final wardId = data['wardId'] as String?;
                      // Keep only global
                      return wardId == null;
                    }).toList();
                  }
                  else {
                    // Admin sees all
                    relevantAnnouncements = allAnnouncements;
                  }
                  // --- End client-side filtering ---

                  if (relevantAnnouncements.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Text(
                          'No relevant announcements at the moment.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    );
                  }


                  return ListView.builder(
                    itemCount: relevantAnnouncements.length, // Use filtered list
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemBuilder: (context, index) {
                      final doc = relevantAnnouncements[index]; // Use filtered list
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final createdBy = data['createdBy'] as String?;
                      // Determine if it's a supervisor post based on whether createdBy matches current user if they are a supervisor
                      // A more robust check might involve fetching the creator's role if needed for display styling.
                      final bool isSupervisorPostGeneral = createdBy != null && createdBy != 'admin_placeholder_uid'; // Simple heuristic
                      final bool canDelete = widget.userData.role == 'admin' || (widget.userData.role == 'supervisor' && createdBy == widget.userData.uid);

                      // --- Pass creator info and delete callback to card ---
                      return AnnouncementCard(
                        doc: doc,
                        showCreator: true, // Show creator info for clarity
                        isSupervisorPost: isSupervisorPostGeneral, // Pass flag indicating if it was likely a supervisor post
                        onDelete: canDelete ? () => _deleteAnnouncement(context, doc.id) : null,
                      )
                          .animate()
                          .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                          .slideY(begin: 0.5, curve: Curves.easeOut);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- Delete function (needed if showing delete button here) ---
  Future<void> _deleteAnnouncement(BuildContext context, String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Delete Announcement?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete this announcement?',
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
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
        if (!mounted) return; // Check mounted before showing snackbar
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully.')),
        );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete announcement: $e')),
        );
      }
    }
  }

}