import 'dart:async';
import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/models/water_tank_model.dart';
import 'package:aquasense/screens/announcements/announcements_screen.dart';
import 'package:aquasense/screens/billing/billing_history_screen.dart';
import 'package:aquasense/screens/connections/apply_connection_screen.dart';
import 'package:aquasense/screens/connections/connection_status_detail_screen.dart';
import 'package:aquasense/screens/home/components/apply_connection_card.dart';
import 'package:aquasense/screens/home/components/connection_status_card.dart';
import 'package:aquasense/screens/home/components/home_header.dart';
import 'package:aquasense/screens/home/components/quick_action_card.dart';
import 'package:aquasense/screens/home/components/water_usage_card.dart';
import 'package:aquasense/screens/report/report_leak_screen.dart';
import 'package:aquasense/screens/statistics/usage_statistics_screen.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/utils/auth_service.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:aquasense/widgets/animated_water_tank.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

// --- NEW IMPORTS ---
import 'package:aquasense/screens/health/components/hydration_card.dart';
import 'package:aquasense/screens/health/hydration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late Stream<UserData?> _userDataStream;
  StreamSubscription? _billingHistorySubscription;

  bool _hasNewAnnouncements = false;
  StreamSubscription? _newAnnouncementsSubscription;
  Timestamp? _lastReadTimestamp;
  UserData? _citizenData;
  StreamSubscription? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint("HomeScreen: initState called.");
    _setupUserDataListener();
    _userDataStream = _userDataListenerStream();
    _fetchInitialCitizenData();
    if (_citizenData?.hasActiveConnection ?? false) {
      _setupBillingHistoryListener();
    }
  }

  Stream<UserData?> _userDataListenerStream() {
    if (currentUser == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserData.fromFirestore(doc) : null)
        .handleError((error) {
      debugPrint("HomeScreen: Error listening to user data stream: $error");
      return null;
    });
  }

  Future<void> _fetchInitialCitizenData() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && mounted) {
        final initialData = UserData.fromFirestore(doc);
        if (_citizenData == null) {
          _citizenData = initialData;
          _lastReadTimestamp = initialData.lastReadAnnouncementsTimestamp;
          _setupNewAnnouncementsCheck();
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("HomeScreen: Error fetching initial citizen data: $e");
    }
  }

  void _setupUserDataListener() {
    if (currentUser == null) return;
    _userDataSubscription = _userDataListenerStream().listen((userData) {
      if (userData != null && mounted) {
        bool needsRebuild = false;
        bool timestampChanged = false;
        bool connectionStatusChanged = (_citizenData?.hasActiveConnection ?? false) != userData.hasActiveConnection;

        _citizenData = userData;
        needsRebuild = true;

        final newTimestamp = userData.lastReadAnnouncementsTimestamp;
        if (_lastReadTimestamp != newTimestamp) {
          _lastReadTimestamp = newTimestamp;
          timestampChanged = true;
        }

        if (connectionStatusChanged) {
          if (userData.hasActiveConnection) {
            _setupBillingHistoryListener();
          } else {
            if (mounted) {
              setState(() {
                _billingHistorySubscription?.cancel();
                _billingHistorySubscription = null;
              });
            }
          }
        } else if (userData.hasActiveConnection && _billingHistorySubscription == null) {
          _setupBillingHistoryListener();
        }

        if (timestampChanged) {
          _setupNewAnnouncementsCheck();
        }

        if (needsRebuild && mounted) {
          setState(() {});
        }
      } else if (mounted) {
        _citizenData = null;
        _billingHistorySubscription?.cancel();
        _billingHistorySubscription = null;
        setState(() {});
      }
    }, onError: (error) {
      if (mounted) {
        _citizenData = null;
        _billingHistorySubscription?.cancel();
        _billingHistorySubscription = null;
        setState(() {});
      }
    });
  }

  void _setupBillingHistoryListener() {
    if (_citizenData == null || !_citizenData!.hasActiveConnection || _billingHistorySubscription != null) {
      return;
    }
    _billingHistorySubscription = _firestoreService.getBillingHistoryStream().listen(
            (billingHistory) {
          // Real IoT/ML logic will be triggered here in the Main Project phase.
        }, onError: (error) {
      debugPrint("HomeScreen: Error listening to billing history: $error");
    });
  }

  Future<void> _setupNewAnnouncementsCheck() async {
    _newAnnouncementsSubscription?.cancel();

    if (_citizenData == null) return;

    bool foundNew = false;
    try {
      // Check Global Announcements
      Query globalQuery = FirebaseFirestore.instance
          .collection('announcements')
          .where('wardId', isEqualTo: null)
          .orderBy('createdAt', descending: true)
          .limit(1);
      if (_lastReadTimestamp != null) {
        globalQuery = globalQuery.where('createdAt', isGreaterThan: _lastReadTimestamp!);
      }
      final globalSnapshot = await globalQuery.get();
      if (globalSnapshot.docs.isNotEmpty) foundNew = true;

      // Check Ward-Specific Announcements
      if (!foundNew && _citizenData!.wardId.isNotEmpty) {
        Query wardQuery = FirebaseFirestore.instance
            .collection('announcements')
            .where('wardId', isEqualTo: _citizenData!.wardId)
            .orderBy('createdAt', descending: true)
            .limit(1);
        if (_lastReadTimestamp != null) {
          wardQuery = wardQuery.where('createdAt', isGreaterThan: _lastReadTimestamp!);
        }
        final wardSnapshot = await wardQuery.get();
        if (wardSnapshot.docs.isNotEmpty) foundNew = true;
      }
    } catch (e) {
      debugPrint("HomeScreen: Error checking for new announcements: $e");
      foundNew = false;
    }

    if (mounted && _hasNewAnnouncements != foundNew) {
      setState(() {
        _hasNewAnnouncements = foundNew;
      });
    }
  }

  @override
  void dispose() {
    _newAnnouncementsSubscription?.cancel();
    _userDataSubscription?.cancel();
    _billingHistorySubscription?.cancel();
    super.dispose();
  }

  Stream<ConnectionRequest?> getConnectionRequestStream() {
    if (currentUser == null) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('connection_requests')
        .where('userId', isEqualTo: currentUser!.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return ConnectionRequest.fromFirestore(snapshot.docs.first);
    });
  }

  void _showFeatureDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Feature Locked", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This feature will be unlocked once your water connection is active.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupervisorContactDialog(BuildContext context, String wardId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    UserData? supervisor;
    try {
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('wardId', isEqualTo: wardId)
          .where('role', isEqualTo: 'supervisor')
          .get();

      if (supervisorQuery.docs.isNotEmpty) {
        final candidates = supervisorQuery.docs
            .map(UserData.fromFirestore)
            .toList();
        final filtered = candidates.where((user) {
          final email = user.email.toLowerCase();
          final hasPhone = (user.phoneNumber ?? '').trim().isNotEmpty;
          final looksLikeDevice = email.startsWith('esp32_') || email.contains('sensor');
          return hasPhone && !looksLikeDevice && !user.isSystemUser;
        }).toList();
        supervisor = filtered.isNotEmpty ? filtered.first : candidates.first;
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text("Error finding supervisor: ${e.toString()}"),
          backgroundColor: Colors.red)
      );
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ward Supervisor Info", style: TextStyle(color: Colors.white)),
        content: supervisor == null
            ? const Text("No supervisor assigned to your ward yet.", style: TextStyle(color: Colors.white70))
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(supervisor.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.call, color: Colors.cyanAccent),
              title: Text(supervisor.phoneNumber ?? 'Not available', style: const TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
              onTap: supervisor.phoneNumber != null ? () async {
                final uri = Uri.parse('tel:${supervisor!.phoneNumber}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              } : null,
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email, color: Colors.cyanAccent),
              title: Text(supervisor.email, style: const TextStyle(color: Colors.white)),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final uri = Uri.parse('mailto:${supervisor!.email}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<UserData?>(
        stream: _userDataStream,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting && _citizenData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if ((userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) && _citizenData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load user data.', style: TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () => _authService.logoutUser(),
                      child: const Text("Logout"))
                ],
              ),
            );
          }

          final userData = _citizenData;
          if (userData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                HomeHeader(
                  userName: userData.name,
                  hasNewAnnouncements: _hasNewAnnouncements,
                  onNotificationTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AnnouncementsScreen(userData: userData))
                    ).then((_) {
                      _setupNewAnnouncementsCheck();
                    });
                  },
                ),

                if (userData.hasActiveConnection)
                  _buildWaterTankDisplay(userData.wardId)
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),

                StreamBuilder<ConnectionRequest?>(
                    stream: getConnectionRequestStream(),
                    builder: (context, requestSnapshot) {
                      final hasConnectionRequest = requestSnapshot.hasData && requestSnapshot.data != null;
                      final noConnectionAndNoRequest = !userData.hasActiveConnection && !hasConnectionRequest;

                      if (noConnectionAndNoRequest) {
                        return _buildNoConnectionMessage();
                      }

                      if (userData.hasActiveConnection) {
                        return WaterUsageCard(userData: userData);
                      }

                      if (hasConnectionRequest) {
                        return ConnectionStatusCard(
                            request: requestSnapshot.data!,
                            onTap: () {
                              Navigator.of(context).push(
                                SlideFadeRoute(
                                  page: ConnectionStatusDetailScreen(request: requestSnapshot.data!),
                                ),
                              );
                            }
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                ),

                // --- INTEGRATED HYDRATION CARD ---
                SliverToBoxAdapter(
                  child: HydrationCard(
                    onTap: () {
                      Navigator.of(context).push(
                        SlideFadeRoute(page: const HydrationScreen()),
                      );
                    },
                  ),
                ),
                // ---------------------------------

                StreamBuilder<ConnectionRequest?>(
                    stream: getConnectionRequestStream(),
                    builder: (context, requestSnapshot) {
                      final hasConnectionRequest = requestSnapshot.hasData && requestSnapshot.data != null;
                      final shouldShowApplyCard = !userData.hasActiveConnection && !hasConnectionRequest;

                      if (shouldShowApplyCard) {
                        return ApplyConnectionCard(
                          onTap: () {
                            Navigator.of(context).push(
                              SlideFadeRoute(page: const ApplyConnectionScreen()),
                            );
                          },
                        );
                      }
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                ),

                _buildQuickActions(userData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaterTankDisplay(String wardId) {
    if (wardId.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('water_tanks').doc(wardId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) { return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator())); }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }
            final tank = WaterTank.fromFirestore(snapshot.data!);
            return SizedBox( height: 190, child: AnimatedWaterTank( waterLevel: tank.level, tankName: tank.tankName, ), );
          },
        ),
      ),
    );
  }

  Widget _buildNoConnectionMessage() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.teal.withAlpha(30),
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(color: Colors.tealAccent.withAlpha(51)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.tealAccent, size: 30),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Apply for a connection to access billing & usage features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(UserData userData) {
    return SliverPadding(
      padding: const EdgeInsets.all(24.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
        ),
        delegate: SliverChildListDelegate(
          [
            QuickActionCard(
              title: 'Contact\nSupervisor',
              icon: Icons.support_agent_outlined,
              color: Colors.purpleAccent,
              onTap: () => _showSupervisorContactDialog(context, userData.wardId),
            ),

            QuickActionCard(
              title: 'Report an\nIssue',
              icon: Icons.report_problem_outlined,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.of(context)
                    .push(SlideFadeRoute(page: const ReportLeakScreen()));
              },
            ),

            QuickActionCard(
              title: 'Billing\nHistory',
              icon: Icons.receipt_long_outlined,
              color: userData.hasActiveConnection ? Colors.orangeAccent : Colors.grey,
              onTap: () {
                if (userData.hasActiveConnection) {
                  Navigator.of(context)
                      .push(SlideFadeRoute(page: const BillingHistoryScreen()));
                } else {
                  _showFeatureDisabledDialog(context);
                }
              },
            ),

            QuickActionCard(
              title: 'Usage\nStatistics',
              icon: Icons.bar_chart_outlined,
              color: userData.hasActiveConnection ? Colors.greenAccent : Colors.grey,
              onTap: () {
                if (userData.hasActiveConnection) {
                  Navigator.of(context)
                      .push(SlideFadeRoute(page: const UsageStatisticsScreen()));
                } else {
                  _showFeatureDisabledDialog(context);
                }
              },
            ),
          ]
              .animate(interval: 100.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.5, curve: Curves.easeOut),
        ),
      ),
    );
  }
}