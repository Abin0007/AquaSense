import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/supervisor/components/tank_level_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TankLevelsScreen extends StatefulWidget {
  const TankLevelsScreen({super.key});

  @override
  State<TankLevelsScreen> createState() => _TankLevelsScreenState();
}

class _TankLevelsScreenState extends State<TankLevelsScreen> {
  // Future to hold the supervisor's ward ID
  late Future<String?> _supervisorWardIdFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the ward ID when the screen initializes
    _supervisorWardIdFuture = _getSupervisorWardId();
  }

  // Fetches the wardId for the currently logged-in supervisor
  Future<String?> _getSupervisorWardId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return userDoc.data()?['wardId'];
    } catch (e) {
      debugPrint("Error fetching supervisor ward ID: $e");
      return null;
    }
  }

  // Method to show the update dialog (Preserved for manual backup)
  void _showUpdateDialog(BuildContext context, WaterTank tank) {
    final TextEditingController levelController = TextEditingController(text: tank.level.toString());
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C5364),
          title: Text('Update ${tank.tankName.replaceAll('%20', ' ')} Level', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter new water level percentage (0-100):', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              TextField(
                controller: levelController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "e.g., 75",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Update'),
              onPressed: () async {
                final newLevel = int.tryParse(levelController.text);
                if (newLevel != null && newLevel >= 0 && newLevel <= 100) {
                  try {
                    await FirebaseFirestore.instance.collection('water_tanks').doc(tank.id).update({
                      'level': newLevel,
                      'lastUpdated': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) Navigator.of(dialogContext).pop();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update tank level: ${e.toString()}'), backgroundColor: Colors.red)
                      );
                    }
                  }

                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid number between 0 and 100.'), backgroundColor: Colors.red)
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Tank Water Levels', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF152D4E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<String?>(
        future: _supervisorWardIdFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Could not find supervisor's ward.", style: TextStyle(color: Colors.white70)));
          }

          // --- FIX: Use the raw ward ID (e.g., "Ward A") directly ---
          final supervisorWardId = snapshot.data!;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('water_tanks').doc(supervisorWardId).snapshots(),
            builder: (context, tankSnapshot) {
              if (tankSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (tankSnapshot.hasError) {
                return Center(child: Text('Error: ${tankSnapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (!tankSnapshot.hasData || !tankSnapshot.data!.exists) {
                return const Center(
                  child: Text('No tank data available for your ward.', style: TextStyle(color: Colors.white70)),
                );
              }

              final tank = WaterTank.fromFirestore(tankSnapshot.data!);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0, left: 4),
                    child: Text(
                      "LIVE SENSOR DATA",
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                  TankLevelCard(
                    tank: tank,
                    onUpdate: () => _showUpdateDialog(context, tank),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideX(begin: -0.2),
                ],
              );
            },
          );
        },
      ),
    );
  }
}