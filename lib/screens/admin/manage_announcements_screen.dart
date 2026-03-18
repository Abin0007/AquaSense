import 'package:aquasense/screens/announcements/components/announcement_card.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);
const Color _dangerRed = Color(0xFFFF4B2B);

class ManageAnnouncementsScreen extends StatefulWidget {
  const ManageAnnouncementsScreen({super.key});

  @override
  State<ManageAnnouncementsScreen> createState() => _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState extends State<ManageAnnouncementsScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        // Admins post globally, so wardId is left null/empty by design
      });

      _titleController.clear();
      _messageController.clear();
      _formKey.currentState?.reset();
      if (!mounted) return;
      FocusScope.of(context).unfocus();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Global Announcement Broadcasted!', style: TextStyle(color: Colors.black)), backgroundColor: Colors.greenAccent),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to post: $e', style: const TextStyle(color: Colors.white)), backgroundColor: _dangerRed),
      );
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF152D4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _dangerRed.withValues(alpha: 0.5))),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: _dangerRed),
            SizedBox(width: 8),
            Text('Delete Broadcast?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this announcement from the network?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Broadcast removed.', style: TextStyle(color: Colors.black)), backgroundColor: Colors.greenAccent));
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e', style: const TextStyle(color: Colors.white)), backgroundColor: _dangerRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashStart,
      appBar: AppBar(
        title: const Text('Global Broadcasts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_dashStart, _dashMid, _dashEnd],
            ),
          ),
          child: Column(
            children: [
              // --- 1. Broadcast Composer Section ---
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.campaign, color: _cyanCustom, size: 24),
                          SizedBox(width: 10),
                          Text("NEW BROADCAST", style: TextStyle(color: _cyanCustom, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ],
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 20),

                      CustomInput(
                        controller: _titleController,
                        hintText: 'Headline / Title',
                        icon: Icons.title,
                        glowAnimation: _glowController,
                        validator: (value) => value!.trim().isEmpty ? 'Headline required.' : null,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                      const SizedBox(height: 16),

                      CustomInput(
                        controller: _messageController,
                        hintText: 'Broadcast Message',
                        icon: Icons.message_outlined,
                        keyboardType: TextInputType.multiline,
                        glowAnimation: _glowController,
                        validator: (value) => value!.trim().isEmpty ? 'Message required.' : null,
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _postAnnouncement,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _cyanCustom,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: _cyanCustom.withValues(alpha: 0.4),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                            : const Text('PUBLISH TO NETWORK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Divider(color: Colors.white10, height: 1),
              ),

              // --- 2. Live Broadcast List Section ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('announcements').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _cyanCustom));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Network Error.', style: TextStyle(color: _dangerRed)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No active broadcasts in the network.', style: TextStyle(color: Colors.white54)));
                    }

                    final announcements = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final doc = announcements[index];
                        return Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: AnnouncementCard(doc: doc),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _dashStart.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: _dangerRed, size: 20),
                                    onPressed: () => _deleteAnnouncement(doc.id),
                                    tooltip: 'Delete Broadcast',
                                  ),
                                ),
                              ),
                            ]
                        ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.05);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}