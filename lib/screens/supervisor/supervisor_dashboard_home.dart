import 'dart:async';
import 'dart:ui'; // Import for ImageFilter
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart';
import 'package:aquasense/screens/supervisor/manage_ward_announcements_screen.dart';
import 'package:aquasense/screens/supervisor/settle_payments_screen.dart';
import 'package:aquasense/screens/supervisor/tank_levels_screen.dart';
import 'package:aquasense/screens/supervisor/view_complaints_screen.dart';
import 'package:aquasense/screens/supervisor/view_connection_requests_screen.dart';
import 'package:aquasense/screens/supervisor/ward_management/ward_member_list_screen.dart'; // Keep for navigation targets
import 'package:aquasense/utils/page_transition.dart';
import 'package:aquasense/widgets/animated_water_tank.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rxdart/rxdart.dart'; // Import rxdart for combining streams

import 'package:aquasense/screens/home/components/quick_action_card.dart';

// --- NEW IoT IMPORTS ---
import 'package:aquasense/models/pipeline_node_model.dart';
import 'package:aquasense/services/iot_service.dart';
import 'package:aquasense/screens/supervisor/iot/pipeline_health_screen.dart';

// This widget now represents ONLY the content of the Supervisor's "Home" tab
class SupervisorDashboardHome extends StatefulWidget {
  const SupervisorDashboardHome({super.key});

  @override
  State<SupervisorDashboardHome> createState() => _SupervisorDashboardHomeState();
}

class _SupervisorDashboardHomeState extends State<SupervisorDashboardHome> {
  late Future<UserData?> _supervisorDataFuture;
  bool _lowLevelAlertShown = false;
  bool _highLevelAlertShown = false;
  bool _hasNewAnnouncements = false;
  // Combine streams subscription
  StreamSubscription? _announcementsSubscription;
  Timestamp? _lastReadTimestamp;
  UserData? _supervisorData;
  StreamSubscription? _userDataSubscription;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _supervisorDataFuture = _fetchInitialSupervisorData();
    _setupUserDataListener();
  }

  Future<UserData?> _fetchInitialSupervisorData() async {
    if (_currentUser == null) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (doc.exists && mounted) {
        final userData = UserData.fromFirestore(doc);
        if (_supervisorData == null) { // Only set initially if not already set by listener
          debugPrint("Setting initial supervisor data and triggering announcement check.");
          _supervisorData = userData;
          _lastReadTimestamp = userData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsStream(); // Initial setup
        }
        return userData;
      }
    } catch (e) {
      debugPrint("Error fetching initial supervisor data: $e");
    }
    return null;
  }

  Stream<UserData?> _userDataListenerStream() {
    if (_currentUser == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserData.fromFirestore(doc) : null)
        .handleError((error) {
      debugPrint("Error listening to user data: $error");
      return null;
    });
  }

  void _setupUserDataListener() {
    if (_currentUser == null) return;
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      if (userData != null && mounted) {
        bool needsRebuildForData = false;
        bool timestampChanged = false;

        // Check if user data itself changed (e.g., wardId, name)
        if (_supervisorData?.uid != userData.uid || _supervisorData?.wardId != userData.wardId) {
          debugPrint("Supervisor data or ward changed.");
          _supervisorData = userData;
          needsRebuildForData = true; // Need to update UI potentially dependent on ward etc.
        }

        // Check if the last read timestamp changed
        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        if (_lastReadTimestamp != newTimestamp) {
          debugPrint("Last read timestamp changed. Old: $_lastReadTimestamp, New: $newTimestamp");
          _lastReadTimestamp = newTimestamp;
          _supervisorData = userData; // Update local copy
          timestampChanged = true;
          // Re-setup the announcement stream because the comparison point changed
          _setupNewAnnouncementsStream();
        } else if (_supervisorData == null) {
          // If supervisor data was initially null but now we have it
          debugPrint("Supervisor data initialized by listener.");
          _supervisorData = userData;
          _lastReadTimestamp = newTimestamp;
          timestampChanged = true; // Consider it a change to trigger setup
          _setupNewAnnouncementsStream();
        }

        // Trigger UI rebuild only if core data changed
        if (needsRebuildForData) {
          debugPrint("Triggering setState due to core supervisor data change.");
          setState(() {
            _supervisorDataFuture = Future.value(userData); // Update future for initial builds
          });
        }

      } else if (mounted) {
        debugPrint("User data listener received null data (user logged out?).");
        _supervisorData = null;
        _announcementsSubscription?.cancel(); // Stop listening
        setState(() {
          _supervisorDataFuture = Future.value(null);
        });
      }
    });
  }

  // --- Setup stream to combine global and ward announcements ---
  void _setupNewAnnouncementsStream() {
    _announcementsSubscription?.cancel(); // Cancel previous subscription
    _hasNewAnnouncements = false; // Reset flag

    if (_supervisorData == null || _supervisorData!.wardId.isEmpty) {
      debugPrint("Cannot check announcements, supervisor data or wardId missing.");
      if(mounted && _hasNewAnnouncements != false) { // Ensure UI reflects no new ones
        setState(() => _hasNewAnnouncements = false);
      }
      return;
    }

    final String wardId = _supervisorData!.wardId;
    debugPrint("Setting up announcement stream. Ward: $wardId, LastRead: ${_lastReadTimestamp?.toDate()}");

    // --- Query 1: Global Announcements ---
    Query queryGlobal = FirebaseFirestore.instance
        .collection('announcements')
        .where('wardId', isEqualTo: null) // Global
        .orderBy('createdAt', descending: true);
    // Apply timestamp filter if available
    if (_lastReadTimestamp != null) {
      queryGlobal = queryGlobal.where('createdAt', isGreaterThan: _lastReadTimestamp!);
    }
    Stream<QuerySnapshot> globalStream = queryGlobal.snapshots();


    // --- Query 2: Ward Announcements ---
    Query queryWard = FirebaseFirestore.instance
        .collection('announcements')
        .where('wardId', isEqualTo: wardId) // Ward specific
        .orderBy('createdAt', descending: true);
    // Apply timestamp filter if available
    if (_lastReadTimestamp != null) {
      queryWard = queryWard.where('createdAt', isGreaterThan: _lastReadTimestamp!);
    }
    Stream<QuerySnapshot> wardStream = queryWard.snapshots();


    // --- Combine Streams using rxdart ---
    _announcementsSubscription = CombineLatestStream.combine2(
      globalStream,
      wardStream,
          (QuerySnapshot globalSnapshot, QuerySnapshot wardSnapshot) {
        // Check if either snapshot contains documents (meaning new announcements exist)
        return globalSnapshot.docs.isNotEmpty || wardSnapshot.docs.isNotEmpty;
      },
    ).listen((bool hasNew) {
      if (mounted && _hasNewAnnouncements != hasNew) {
        debugPrint("New announcement status changed: $hasNew");
        setState(() {
          _hasNewAnnouncements = hasNew;
        });
      }
    }, onError: (error) {
      debugPrint("Error listening to combined announcements stream: $error");
      if (mounted && _hasNewAnnouncements) {
        setState(() => _hasNewAnnouncements = false); // Reset on error
      }
    });
  }

  void _showWaterLevelAlert(BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF152D4E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 60)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack)
                  .then(delay: 100.ms)
                  .shake(hz: 4, duration: 300.ms),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("DISMISS", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _announcementsSubscription?.cancel(); // Cancel combined stream
    _userDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: FutureBuilder<UserData?>(
        future: _supervisorDataFuture,
        builder: (context, snapshot) {
          // Use _supervisorData for checks after initial load completes
          final currentSupervisorData = _supervisorData;

          if (snapshot.connectionState == ConnectionState.waiting && currentSupervisorData == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if ((snapshot.hasError || !snapshot.hasData || snapshot.data == null) && currentSupervisorData == null) {
            return const Center(
                child: Text("Could not load supervisor data.", style: TextStyle(color: Colors.redAccent)));
          }

          // Use the locally stored supervisor data for building the UI
          final supervisorData = currentSupervisorData!;

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Dashboard'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (_hasNewAnnouncements)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent, shape: BoxShape.circle,
                            ),
                          ).animate(onPlay: (c)=> c.repeat(reverse: true)).scaleXY(end: 1.2, duration: 600.ms).fade(),
                        ),
                    ],
                  ),
                  tooltip: 'View Announcements',
                  onPressed: () {
                    // Pass the most recent supervisor data
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: supervisorData)))
                        .then((_) => _setupNewAnnouncementsStream()); // Re-check after returning
                  },
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 16, top: 0), // Adjusted top/bottom padding
              children: [
                const _SectionHeader(title: 'Live Tank Status', topPadding: 16), // Reduced top padding
                _buildWaterTankDisplay(supervisorData.wardId),

                // --- PIPELINE HEALTH SECTION ---
                const _SectionHeader(title: 'Pipeline Health (IoT)'),
                _buildPipelineHealthCard(supervisorData.wardId),

                const _SectionHeader(title: 'Quick Actions'),
                _buildQuickActionsGrid(supervisorData), // Pass the data
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaterTankDisplay(String supervisorWardId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Adjusted vertical padding
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('water_tanks')
            .doc(supervisorWardId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 190,
                child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Center(
                  child: Text('No tank data available for your ward.',
                      style: TextStyle(color: Colors.white70))),
            );
          }
          final tank = WaterTank.fromFirestore(snapshot.data!);

          // Alert logic
          if (tank.level <= 15 && !_lowLevelAlertShown) {
            _showWaterLevelAlert( context, title: "Critical Low Level!", message: "Water level is at ${tank.level}%. Risk of motor damage from dry running. Immediate action required.", icon: Icons.error_outline, color: Colors.redAccent, );
            _lowLevelAlertShown = true; _highLevelAlertShown = false;
          } else if (tank.level >= 90 && !_highLevelAlertShown) {
            _showWaterLevelAlert( context, title: "Tank Almost Full", message: "Water level has reached ${tank.level}%. Prepare to turn off the motor to prevent overflow.", icon: Icons.notifications_active_outlined, color: Colors.amberAccent, );
            _highLevelAlertShown = true; _lowLevelAlertShown = false;
          } else if (tank.level > 15 && tank.level < 90) {
            if (_lowLevelAlertShown || _highLevelAlertShown) {
              WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { setState(() { _lowLevelAlertShown = false; _highLevelAlertShown = false; }); } });
            }
          }
          return SizedBox(
            height: 190,
            child: AnimatedWaterTank(
              waterLevel: tank.level,
              tankName: tank.tankName,
            ),
          );
        },
      ),
    );
  }

  // --- UPDATED PIPELINE HEALTH CARD (DYNAMIC WARNING) ---
  Widget _buildPipelineHealthCard(String supervisorWardId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: StreamBuilder<PipelineNode?>(
        stream: IoTService().streamWardPipelineData(supervisorWardId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          // Fallback if no sensor is assigned to this ward yet
          if (!snapshot.hasData || snapshot.data == null) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sensors_off, color: Colors.grey),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text("No pipeline sensors deployed in your ward yet.", style: TextStyle(color: Colors.white70)),
                  )
                ],
              ),
            );
          }

          final node = snapshot.data!;
          // NEW LEAK LOGIC: Auto-detects leak if Flow In is significantly greater than Flow Out
          final isLeaking = node.status == 'Leak Detected' || (node.flowRateIn - node.flowRateOut) > 0.5;

          return GestureDetector(
            onTap: () => Navigator.push(context, SlideFadeRoute(page: PipelineHealthScreen(wardId: supervisorWardId))),
            child: isLeaking
                ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9), // Solid red alert
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32)
                          .animate(onPlay: (c) => c.repeat()).fadeOut(duration: 500.ms).fadeIn(duration: 500.ms),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text("CRITICAL LEAK DETECTED", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Pipeline integrity failure in your ward. Variance: ${(node.flowRateIn - node.flowRateOut).toStringAsFixed(1)} L/min.", style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("TAP TO INITIATE EMERGENCY PROTOCOL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1)
            // Normal State Card
                : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Ward Pipeline Status", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text("System Normal", style: TextStyle(color: Colors.greenAccent)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ).animate().fadeIn(),
          );
        },
      ),
    );
  }

  // Extracted Grid logic
  Widget _buildQuickActionsGrid(UserData supervisorData) {
    final List<Widget> gridItems = [
      QuickActionCard(
        title: 'Ward Members',
        icon: Icons.group_outlined,
        color: Colors.tealAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: const WardMemberListScreen())),
      ),
      QuickActionCard(
        title: 'Manage Ward\nAnnouncements',
        icon: Icons.campaign_outlined,
        color: Colors.lightBlueAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: ManageWardAnnouncementsScreen(wardId: supervisorData.wardId))),
      ),
      QuickActionCard(
        title: 'View Ward\nComplaints',
        icon: Icons.error_outline,
        color: Colors.orangeAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: const ViewComplaintsScreen())),
      ),
      QuickActionCard(
        title: 'Approve\nConnections',
        icon: Icons.person_add_alt_outlined,
        color: Colors.blueAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: const ViewConnectionRequestsScreen())),
      ),
      QuickActionCard(
        title: 'Tank Levels',
        icon: Icons.opacity,
        color: Colors.greenAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: const TankLevelsScreen())),
      ),
      QuickActionCard(
        title: 'Settle Cash\nPayments',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.purpleAccent,
        onTap: () => Navigator.of(context).push(SlideFadeRoute(page: const SettlePaymentsScreen())),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: gridItems
            .animate(interval: 80.ms)
            .fadeIn(duration: 300.ms)
            .scaleXY(begin: 0.8, curve: Curves.easeOut),
      ),
    );
  }
}

// --- Reusable Section Header ---
class _SectionHeader extends StatelessWidget {
  final String title;
  final double topPadding;
  const _SectionHeader({required this.title, this.topPadding = 24});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: topPadding, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    ).animate().fadeIn();
  }
}