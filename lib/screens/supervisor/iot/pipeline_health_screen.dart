import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/pipeline_node_model.dart';
import '../../../models/leak_log_model.dart';
import '../../../services/iot_service.dart';
import '../../../services/storage_service.dart';
import '../../../utils/page_transition.dart';
import 'pipeline_history_screen.dart';
import 'manage_sensors_screen.dart';

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);
const Color _dangerRed = Color(0xFFFF4B2B);

class PipelineHealthScreen extends StatefulWidget {
  final String wardId;
  const PipelineHealthScreen({super.key, required this.wardId});

  @override
  State<PipelineHealthScreen> createState() => _PipelineHealthScreenState();
}

class _PipelineHealthScreenState extends State<PipelineHealthScreen> {
  final IoTService _ioTService = IoTService();

  // --- NEW: Helper to fetch GPS for the Add Sensor feature ---
  Future<GeoPoint?> _fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable Location Services.')));
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(position.latitude, position.longitude);
  }

  // --- NEW: Bottom Sheet to Add Sensor ---
  void _showAddSensorModal() {
    final nameController = TextEditingController();
    final areaController = TextEditingController();
    GeoPoint? fetchedLoc;
    bool isFetching = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF152D4E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  const Text("Deploy New Sensor", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Register a new IoT node for this ward.", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 24),

                  // Sensor Name
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Sensor Name / ID",
                      labelStyle: const TextStyle(color: _cyanCustom),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyanCustom)),
                      prefixIcon: const Icon(Icons.sensors, color: _cyanCustom),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Checkpoint Area
                  TextField(
                    controller: areaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Checkpoint Name / Area",
                      labelStyle: const TextStyle(color: _cyanCustom),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cyanCustom)),
                      prefixIcon: const Icon(Icons.place, color: _cyanCustom),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // GPS Location Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.gps_fixed, color: fetchedLoc != null ? Colors.greenAccent : Colors.white54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("GPS Coordinates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(
                                fetchedLoc != null ? "${fetchedLoc!.latitude.toStringAsFixed(5)}, ${fetchedLoc!.longitude.toStringAsFixed(5)}" : "Not acquired yet",
                                style: TextStyle(color: fetchedLoc != null ? Colors.greenAccent : Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (isFetching)
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _cyanCustom, strokeWidth: 2))
                        else
                          TextButton(
                            onPressed: () async {
                              setModalState(() => isFetching = true);
                              final loc = await _fetchCurrentLocation();
                              setModalState(() {
                                isFetching = false;
                                fetchedLoc = loc;
                              });
                            },
                            child: const Text("FETCH", style: TextStyle(color: _cyanCustom, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyanCustom,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        if (nameController.text.isEmpty || areaController.text.isEmpty || fetchedLoc == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and fetch GPS.", style: TextStyle(color: Colors.white)), backgroundColor: _dangerRed));
                          return;
                        }

                        setModalState(() => isSaving = true);
                        try {
                          // Save to a generic 'deployed_sensors' collection so it doesn't break current dual-sensor UI
                          await FirebaseFirestore.instance.collection('deployed_sensors').add({
                            'wardId': widget.wardId,
                            'sensorName': nameController.text.trim(),
                            'checkpointArea': areaController.text.trim(),
                            'location': fetchedLoc,
                            'deployedAt': FieldValue.serverTimestamp(),
                            'status': 'Pending Network Configuration',
                          });
                          if (mounted) {
                            Navigator.pop(this.context);
                            ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Sensor Deployed Successfully!", style: TextStyle(color: Colors.black)), backgroundColor: _cyanCustom));
                          }
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Error: $e", style: const TextStyle(color: Colors.white)), backgroundColor: _dangerRed));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black))
                          : const Text("SAVE SENSOR DATA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- NEW: Custom Card UI for Adding Sensor ---
  Widget _buildAddSensorButton(BuildContext context) {
    return GestureDetector(
      onTap: _showAddSensorModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _cyanCustom.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cyanCustom.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cyanCustom.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.add_location_alt, color: _cyanCustom, size: 28),
            ),
            const SizedBox(height: 12),
            const Text("Deploy Additional Sensor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text("Register a new checkpoint in this ward", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dashStart, _dashMid, _dashEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- APP BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const Text(
                      'Live Pipeline Health',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                    ),
                    _buildIconButton(
                        Icons.settings_outlined,
                            () => Navigator.push(context, SlideFadeRoute(page: ManageSensorsScreen(wardId: widget.wardId)))
                    ),
                  ],
                ),
              ),

              // --- MAIN CONTENT ---
              Expanded(
                child: StreamBuilder<PipelineNode?>(
                  stream: _ioTService.streamWardPipelineData(widget.wardId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _cyanCustom));
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(child: Text("No IoT Sensors deployed.", style: TextStyle(color: Colors.white70)));
                    }

                    final node = snapshot.data!;
                    final isLeaking = node.status == 'Leak Detected' || (node.flowRateIn - node.flowRateOut) > 0.5;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 40.0),
                      child: Column(
                        children: [
                          if (!isLeaking) ...[
                            _buildStatusBadge(isLeaking).animate().fadeIn().slideY(begin: -0.2),
                            const SizedBox(height: 32),
                          ],

                          // --- ANIMATED PIPE ---
                          AnimatedPipelineVisualizer(isLeaking: isLeaking)
                              .animate()
                              .fadeIn(duration: 800.ms)
                              .scaleXY(begin: 0.95, curve: Curves.easeOut),

                          if (isLeaking) ...[
                            const SizedBox(height: 32),
                            _buildStatusBadge(isLeaking).animate().fadeIn().slideY(begin: 0.2),
                          ] else ...[
                            const SizedBox(height: 32),
                            const Text(
                              "Differential flow analysis indicates zero variance between ingress and egress points.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                            ).animate().fadeIn(delay: 200.ms),
                          ],

                          const SizedBox(height: 40),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "DIFFERENTIAL FLOW ANALYSIS",
                                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                              if (!isLeaking)
                                const Text("REAL-TIME", style: TextStyle(color: _cyanCustom, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ).animate().fadeIn(delay: 300.ms),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildFlowCard(
                                    title: "Flow In", subtitle: "Sensor 1", value: node.flowRateIn, isDanger: false, isOut: false
                                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFlowCard(
                                    title: "Flow Out", subtitle: "Sensor 2", value: node.flowRateOut, isDanger: isLeaking, isOut: true
                                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // --- DYNAMIC TIMELINE OR HISTORY ---
                          if (isLeaking)
                            EmergencyWorkflowTimeline(wardId: widget.wardId, node: node).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2)
                          else
                            _buildFullHistoryButton(context).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),

                          const SizedBox(height: 24),

                          // --- NEW: DEPLOY SENSOR BUTTON (Fills the vacant space) ---
                          _buildAddSensorButton(context).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                        ],
                      ),
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

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatusBadge(bool isLeaking) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLeaking ? Colors.redAccent.withValues(alpha: 0.15) : Colors.greenAccent.withValues(alpha: 0.15),
        border: Border.all(color: isLeaking ? Colors.redAccent.withValues(alpha: 0.5) : Colors.greenAccent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isLeaking ? Colors.redAccent.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.3),
            blurRadius: 15, spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLeaking ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: isLeaking ? Colors.redAccent : Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            isLeaking ? "LEAK DETECTED" : "SYSTEM NORMAL",
            style: TextStyle(color: isLeaking ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard({required String title, required String subtitle, required double value, required bool isDanger, required bool isOut}) {
    final Color accentColor = isDanger ? _dangerRed : _cyanCustom;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isOut ? Icons.arrow_downward : Icons.arrow_upward, color: accentColor, size: 14),
              ),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Container(
                width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: accentColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ).animate(onPlay: (c) => isDanger ? c.repeat() : null).fadeOut(duration: 600.ms).fadeIn(duration: 600.ms),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accentColor),
              ),
              const SizedBox(width: 4),
              const Text("L/min", style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullHistoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, SlideFadeRoute(page: const PipelineHistoryScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("View Full History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DYNAMIC EMERGENCY WORKFLOW TIMELINE
// ============================================================================

class EmergencyWorkflowTimeline extends StatefulWidget {
  final String wardId;
  final PipelineNode node;

  const EmergencyWorkflowTimeline({super.key, required this.wardId, required this.node});

  @override
  State<EmergencyWorkflowTimeline> createState() => _EmergencyWorkflowTimelineState();
}

class _EmergencyWorkflowTimelineState extends State<EmergencyWorkflowTimeline> {
  bool _isLoading = false;

  Future<GeoPoint?> _getLiveLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable Location Services to proceed.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions denied.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(position.latitude, position.longitude);
  }

  Future<void> _launchMap(GeoPoint loc) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  Future<void> _uploadAndProceed(BuildContext context, String logId, String step) async {
    final loc = await _getLiveLocation(context);
    if (loc == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = await StorageService().uploadSupervisorComplaintImage(XFile(pickedFile.path), logId, step);

      if (step == 'arrived') {
        await IoTService().updateLeakWorkflow(logId, {
          'status': 'Investigating',
          'arrivedAt': FieldValue.serverTimestamp(),
          'arrivedPhotoUrl': url,
          'arrivedLocation': loc
        });
      } else if (step == 'resolved') {
        await FirebaseFirestore.instance.collection('pipeline_nodes').doc(widget.node.nodeId).update({
          'status': 'Normal',
          'flowRateOut': widget.node.flowRateIn,
        });

        await IoTService().updateLeakWorkflow(logId, {
          'status': 'Resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedPhotoUrl': url,
          'resolvedLocation': loc
        });
      }
    } catch (e) {
      debugPrint("Error in workflow: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LeakLog?>(
      stream: IoTService().streamActiveLeakLog(widget.wardId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: _cyanCustom);

        if (!snapshot.hasData || snapshot.data == null) {
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => IoTService().initiateLeakProtocol(widget.wardId, widget.node.flowRateIn - widget.node.flowRateOut),
            child: const Text("INITIALIZE EMERGENCY PROTOCOL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          );
        }

        final log = snapshot.data!;

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("EMERGENCY WORKFLOW", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 24),

                  _buildTimelineStep(
                    title: "Shutdown Main Valves",
                    isCompleted: log.valvesShutdownAt != null,
                    isActive: log.valvesShutdownAt == null,
                    isLast: false,
                    content: log.valvesShutdownAt == null
                        ? ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => IoTService().updateLeakWorkflow(log.logId, {'status': 'Valves_Closed', 'valvesShutdownAt': FieldValue.serverTimestamp()}),
                      child: const Text("Confirm Shutdown", style: TextStyle(color: Colors.white)),
                    )
                        : const Text("Valves secured.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),

                  _buildTimelineStep(
                    title: "Locate & Inspect Site",
                    isCompleted: log.arrivedAt != null,
                    isActive: log.valvesShutdownAt != null && log.arrivedAt == null,
                    isLast: false,
                    content: (log.valvesShutdownAt != null && log.arrivedAt == null)
                        ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Leak is between these sensors:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 8),
                        _buildLocationCard("Sensor 1 (In)", widget.node.sensor1Address, widget.node.sensor1Location),
                        const SizedBox(height: 8),
                        _buildLocationCard("Sensor 2 (Out)", widget.node.sensor2Address, widget.node.sensor2Location),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _cyanCustom.withValues(alpha: 0.2), foregroundColor: _cyanCustom),
                          onPressed: () => _uploadAndProceed(context, log.logId, 'arrived'),
                          icon: const Icon(Icons.camera_alt), label: const Text("Log Arrival & Photo"),
                        ),
                      ],
                    )
                        : null,
                  ),

                  _buildTimelineStep(
                    title: "Repair Pipeline",
                    isCompleted: log.status == 'Resolved',
                    isActive: log.arrivedAt != null && log.status != 'Resolved',
                    isLast: true,
                    content: (log.arrivedAt != null && log.status != 'Resolved')
                        ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.withValues(alpha: 0.2), foregroundColor: Colors.greenAccent),
                      onPressed: () => _uploadAndProceed(context, log.logId, 'resolved'),
                      icon: const Icon(Icons.check_circle), label: const Text("Upload Fix & Resolve"),
                    )
                        : null,
                  ),
                ],
              ),
            ),

            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: _cyanCustom),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLocationCard(String label, String address, GeoPoint? loc) {
    return GestureDetector(
      onTap: () {
        if (loc != null) {
          _launchMap(loc);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location data not available for this sensor.')));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_rounded, color: _cyanCustom, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(address, style: const TextStyle(color: Colors.white54, fontSize: 11))
                    ]
                )
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({required String title, required bool isCompleted, required bool isActive, required bool isLast, Widget? content}) {
    Color nodeColor = isCompleted ? Colors.greenAccent : (isActive ? _dangerRed : Colors.white24);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: nodeColor.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: nodeColor)),
                child: isCompleted ? const Icon(Icons.check, size: 12, color: Colors.greenAccent) : (isActive ? Container(margin: const EdgeInsets.all(4), decoration: const BoxDecoration(color: _dangerRed, shape: BoxShape.circle)) : null),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: isCompleted ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white10, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isActive || isCompleted ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (content != null) ...[const SizedBox(height: 12), content],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM PIPELINE ANIMATION WIDGET
// ============================================================================

class AnimatedPipelineVisualizer extends StatefulWidget {
  final bool isLeaking;
  const AnimatedPipelineVisualizer({super.key, required this.isLeaking});

  @override
  State<AnimatedPipelineVisualizer> createState() => _AnimatedPipelineVisualizerState();
}

class _AnimatedPipelineVisualizerState extends State<AnimatedPipelineVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double dx = 0; double dy = 0;
        if (widget.isLeaking) {
          dx = math.sin(_controller.value * math.pi * 30) * 1.0;
          dy = math.cos(_controller.value * math.pi * 30) * 1.0;
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isLeaking)
              Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.08), blurRadius: 80, spreadRadius: 20)],
                ),
              ),
            Transform.translate(
              offset: Offset(dx, dy),
              child: SizedBox(
                height: 180, width: double.infinity,
                child: CustomPaint(painter: PipelinePainter(progress: _controller.value, isLeaking: widget.isLeaking)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PipelinePainter extends CustomPainter {
  final double progress;
  final bool isLeaking;

  PipelinePainter({required this.progress, required this.isLeaking});

  @override
  void paint(Canvas canvas, Size size) {
    const double pipeHeight = 45.0;
    final double pipeY = size.height - pipeHeight - 50;

    final RRect pipeOuter = RRect.fromRectAndRadius(Rect.fromLTWH(20, pipeY, size.width - 40, pipeHeight), const Radius.circular(6));
    final Paint pipePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF4A5568), Color(0xFF718096), Color(0xFFCBD5E0), Color(0xFF718096), Color(0xFF2D3748)],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(pipeOuter.outerRect);

    canvas.drawRRect(pipeOuter.shift(const Offset(0, 15)), Paint()..color = Colors.black45..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawRRect(pipeOuter, pipePaint);

    final Paint jointPaint = Paint()..color = const Color(0xFF2D3748);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10, pipeY - 5, 12, pipeHeight + 10), const Radius.circular(2)), jointPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width - 22, pipeY - 5, 12, pipeHeight + 10), const Radius.circular(2)), jointPaint);

    if (!isLeaking) {
      canvas.save();
      canvas.clipRRect(pipeOuter);

      canvas.drawRRect(pipeOuter, Paint()..color = _cyanCustom.withValues(alpha: 0.15));

      final Paint flowPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, _cyanCustom, Colors.transparent],
        ).createShader(const Rect.fromLTWH(0, 0, 150, pipeHeight));

      for (int i = 0; i < 3; i++) {
        double p = (progress + (i * 0.33)) % 1.0;
        double x = (p * size.width * 1.5) - (size.width * 0.2);

        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, pipeY + 8, 80, pipeHeight - 16), const Radius.circular(20)),
            flowPaint
        );
      }
      canvas.restore();
    }

    if (isLeaking) {
      final double crackX = size.width / 2 - 10;

      final Path crackPath = Path()
        ..moveTo(crackX, pipeY)
        ..lineTo(crackX + 10, pipeY + 10)
        ..lineTo(crackX + 5, pipeY + 25)
        ..lineTo(crackX + 15, pipeY + pipeHeight);

      canvas.drawPath(crackPath, Paint()..color = const Color(0xFF742A2A)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap=StrokeCap.round);

      canvas.drawCircle(Offset(crackX + 5, pipeY), 25, Paint()..color = Colors.blue[300]!.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

      final Paint particlePaint = Paint();
      for (int i = 0; i < 60; i++) {
        double p = (progress + (i * 0.016)) % 1.0;

        double spread = math.sin(i * 45) * 80.0;
        double dx = crackX + (spread * p);
        double force = 180.0 + (math.cos(i * 12) * 60.0);
        double dy = pipeY - (force * p) + (100 * p * p);

        double radius = (1.0 - p) * 3.5;
        double opacity = (1.0 - p).clamp(0.0, 1.0);

        particlePaint.color = (i % 3 == 0) ? Colors.white.withValues(alpha: opacity) : Colors.blue[200]!.withValues(alpha: opacity);
        canvas.drawCircle(Offset(dx, dy), radius, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PipelinePainter oldDelegate) => true;
}