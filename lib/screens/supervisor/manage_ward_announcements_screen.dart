import 'package:aquasense/widgets/custom_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart'; // For date/time formatting

// Re-using the Admin's Announcement Card for display consistency
import 'package:aquasense/screens/announcements/components/announcement_card.dart';

class ManageWardAnnouncementsScreen extends StatefulWidget {
  final String wardId; // Pass the supervisor's ward ID

  const ManageWardAnnouncementsScreen({super.key, required this.wardId});

  @override
  State<ManageWardAnnouncementsScreen> createState() =>
      _ManageWardAnnouncementsScreenState();
}

class _ManageWardAnnouncementsScreenState extends State<ManageWardAnnouncementsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  final String? _supervisorId = FirebaseAuth.instance.currentUser?.uid;

  // State for Water Supply Alert
  bool _isSupplyAlert = false;
  DateTime? _selectedSupplyDate;
  TimeOfDay? _selectedSupplyTime;

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _selectSupplyDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedSupplyDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)), // Allow scheduling up to 30 days ahead
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedSupplyTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Ensure the selected time is in the future
        if (selectedDateTime.isBefore(DateTime.now().add(const Duration(minutes: 16)))) { // At least 16 mins ahead
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Supply time must be at least 16 minutes in the future.'), backgroundColor: Colors.orange),
            );
          }
          return;
        }


        setState(() {
          _selectedSupplyDate = pickedDate;
          _selectedSupplyTime = pickedTime;
        });
      }
    }
  }


  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate() || _supervisorId == null) {
      return;
    }
    if (_isSupplyAlert && (_selectedSupplyDate == null || _selectedSupplyTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time for the supply alert.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Timestamp? supplyTimestamp;
    if (_isSupplyAlert && _selectedSupplyDate != null && _selectedSupplyTime != null) {
      supplyTimestamp = Timestamp.fromDate(DateTime(
        _selectedSupplyDate!.year,
        _selectedSupplyDate!.month,
        _selectedSupplyDate!.day,
        _selectedSupplyTime!.hour,
        _selectedSupplyTime!.minute,
      ));

      // Double check time constraint before sending to Firestore
      if (supplyTimestamp.toDate().isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supply time must be at least 15 minutes in the future.'), backgroundColor: Colors.orange),
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }
    }


    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _isSupplyAlert ? 'Water Supply Alert' : _titleController.text.trim(),
        'message': _isSupplyAlert
            ? 'Water supply for Ward ${widget.wardId} is scheduled to start around ${DateFormat('h:mm a, d MMM').format(supplyTimestamp!.toDate())}.'
            : _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _supervisorId, // Supervisor's UID
        'wardId': widget.wardId, // Supervisor's Ward ID
        'isSupplyAlert': _isSupplyAlert,
        'supplyStartTime': supplyTimestamp,
      });

      // Reset form
      _titleController.clear();
      _messageController.clear();
      _formKey.currentState?.reset();
      setState(() {
        _isSupplyAlert = false;
        _selectedSupplyDate = null;
        _selectedSupplyTime = null;
      });
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Announcement posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to post announcement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
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
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully.')),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete announcement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_supervisorId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Ward Announcements')),
        body: const Center(child: Text("Error: Supervisor not identified.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Manage Ward Announcements'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // --- Form Section ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Water Supply Alert Toggle
                    SwitchListTile(
                      title: const Text('Water Supply Alert?', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Notify users about upcoming supply time.', style: TextStyle(color: Colors.white70)),
                      value: _isSupplyAlert,
                      onChanged: (value) {
                        setState(() {
                          _isSupplyAlert = value;
                          if (!value) {
                            _selectedSupplyDate = null;
                            _selectedSupplyTime = null;
                          } else {
                            _titleController.clear(); // Clear title/message if switching
                            _messageController.clear();
                          }
                        });
                      },
                      activeThumbColor: Colors.cyanAccent,
                      tileColor: Colors.white.withAlpha(15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),

                    const SizedBox(height: 16),

                    // Conditional Inputs based on Alert Type
                    if (_isSupplyAlert) ...[
                      ListTile(
                        leading: const Icon(Icons.timer_outlined, color: Colors.white70),
                        title: Text(
                          _selectedSupplyDate == null || _selectedSupplyTime == null
                              ? 'Select Supply Start Time'
                              : 'Supply Starts: ${DateFormat('h:mm a, d MMM yyyy').format(DateTime(_selectedSupplyDate!.year, _selectedSupplyDate!.month, _selectedSupplyDate!.day, _selectedSupplyTime!.hour, _selectedSupplyTime!.minute))}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.edit_calendar_outlined, color: Colors.cyanAccent),
                        onTap: _selectSupplyDateTime,
                        tileColor: Colors.white.withAlpha(15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ] else ...[
                      CustomInput(
                        controller: _titleController,
                        hintText: 'Announcement Title',
                        icon: Icons.title,
                        glowAnimation: _glowController,
                        validator: (value) => !_isSupplyAlert && value!.trim().isEmpty ? 'Title cannot be empty.' : null,
                      ),
                      const SizedBox(height: 16),
                      CustomInput(
                        controller: _messageController,
                        hintText: 'Announcement Message',
                        icon: Icons.message_outlined,
                        keyboardType: TextInputType.multiline,
                        glowAnimation: _glowController,
                        validator: (value) => !_isSupplyAlert && value!.trim().isEmpty ? 'Message cannot be empty.' : null,
                      ),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _postAnnouncement,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                          : Text(_isSupplyAlert ? 'Post Supply Alert' : 'Post Announcement',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // --- List Section (Only Supervisor's Announcements) ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Your Posted Announcements',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .where('createdBy', isEqualTo: _supervisorId) // Filter by supervisor
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading announcements.',
                            style: TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('You haven\'t posted any announcements yet.',
                            style: TextStyle(color: Colors.white70)));
                  }

                  final announcements = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final doc = announcements[index];
                      // Use Stack to overlay delete button
                      return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              // Pass delete callback here
                              child: AnnouncementCard(doc: doc, onDelete: () => _deleteAnnouncement(doc.id)),
                            ),
                            // Delete button is now inside AnnouncementCard, conditional on onDelete being non-null
                          ]
                      ).animate().fadeIn(delay: (50 * index).ms);
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