import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/pipeline_node_model.dart';

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);
const Color _dangerRed = Color(0xFFFF4B2B);

class ManageSensorsScreen extends StatefulWidget {
  final String wardId;
  const ManageSensorsScreen({super.key, required this.wardId});

  @override
  State<ManageSensorsScreen> createState() => _ManageSensorsScreenState();
}

class _ManageSensorsScreenState extends State<ManageSensorsScreen> {
  bool _isLoading = false;

  // Controllers for addresses/names
  final TextEditingController _sensor1AddressCtrl = TextEditingController();
  final TextEditingController _sensor2AddressCtrl = TextEditingController();

  GeoPoint? _sensor1Loc;
  GeoPoint? _sensor2Loc;
  String? _nodeId;

  @override
  void initState() {
    super.initState();
    _fetchExistingData();
  }

  Future<void> _fetchExistingData() async {
    setState(() => _isLoading = true);
    try {
      // Point directly to the ESP32 hardware document to avoid ghost documents
      final doc = await FirebaseFirestore.instance
          .collection('pipeline_nodes')
          .doc('ward_1_main_pipe')
          .get();

      if (doc.exists && doc.data() != null) {
        final node = PipelineNode.fromMap(doc.data()!, doc.id);
        _nodeId = doc.id;

        setState(() {
          _sensor1AddressCtrl.text = node.sensor1Address;
          _sensor2AddressCtrl.text = node.sensor2Address;
          _sensor1Loc = node.sensor1Location;
          _sensor2Loc = node.sensor2Location;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sensors: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<GeoPoint?> _getLiveLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable Location Services.')));
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(position.latitude, position.longitude);
  }

  Future<void> _saveSensorData() async {
    if (_nodeId == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('pipeline_nodes').doc(_nodeId).update({
        'sensor1Address': _sensor1AddressCtrl.text.trim(),
        'sensor2Address': _sensor2AddressCtrl.text.trim(),
        'sensor1Location': _sensor1Loc,
        'sensor2Location': _sensor2Loc,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Primary Sensor locations updated successfully!', style: TextStyle(color: Colors.black)), backgroundColor: Colors.greenAccent)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: _dangerRed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: DELETE/REMOVE FUNCTIONALITY ---
  void _deleteDocument(String collection, String docId, bool isMainNode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152D4E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _dangerRed.withValues(alpha: 0.5))
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _dangerRed),
            SizedBox(width: 10),
            Text("Remove Sensor?", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          isMainNode
              ? "Removing the Primary Hardware Node will clear its custom GPS coordinates and addresses. \n\n(Note: The ESP32 hardware will automatically recreate the flow rate data on its next ping, but your GPS data will be wiped). \n\nProceed?"
              : "Are you sure you want to permanently remove this deployed checkpoint sensor?",
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Sensor removed successfully.", style: TextStyle(color: Colors.black)), backgroundColor: Colors.greenAccent)
                  );
                  // If main node was deleted, clear the text fields locally
                  if (isMainNode) {
                    setState(() {
                      _nodeId = null;
                      _sensor1AddressCtrl.clear();
                      _sensor2AddressCtrl.clear();
                      _sensor1Loc = null;
                      _sensor2Loc = null;
                    });
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: _dangerRed));
                }
              }
            },
            child: const Text("REMOVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
                    const Text('Manage Checkpoints', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5)),
                    const SizedBox(width: 36), // Empty space for centering
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _cyanCustom))
                    : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // =========================================================
                      // SECTION 1: PRIMARY SYSTEM (Existing Editing Capabilities)
                      // =========================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("PRIMARY SYSTEM", style: TextStyle(color: _cyanCustom, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          if (_nodeId != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: _dangerRed, size: 20),
                              tooltip: "Reset/Remove Main Node",
                              onPressed: () => _deleteDocument('pipeline_nodes', _nodeId!, true),
                            )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Configure physical locations for the main ESP32 flow sensors in this ward. This data is critical for emergency routing.", style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
                      const SizedBox(height: 24),

                      _buildSensorConfigCard(
                        title: "Sensor 1 (Flow In)",
                        controller: _sensor1AddressCtrl,
                        location: _sensor1Loc,
                        onUpdateLocation: () async {
                          final loc = await _getLiveLocation();
                          if (loc != null) setState(() => _sensor1Loc = loc);
                        },
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

                      const SizedBox(height: 16),

                      _buildSensorConfigCard(
                        title: "Sensor 2 (Flow Out)",
                        controller: _sensor2AddressCtrl,
                        location: _sensor2Loc,
                        onUpdateLocation: () async {
                          final loc = await _getLiveLocation();
                          if (loc != null) setState(() => _sensor2Loc = loc);
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyanCustom,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _nodeId == null ? null : _saveSensorData,
                        child: const Text("SAVE PRIMARY CONFIGURATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 48),

                      // =========================================================
                      // SECTION 2: NEWLY DEPLOYED SENSORS LIST
                      // =========================================================
                      const Text("ADDITIONAL CHECKPOINTS", style: TextStyle(color: _cyanCustom, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('deployed_sensors')
                            .where('wardId', isEqualTo: widget.wardId)
                            .orderBy('deployedAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _cyanCustom)));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                              child: const Center(child: Text("No additional sensors deployed yet.", style: TextStyle(color: Colors.white54))),
                            ).animate().fadeIn();
                          }

                          return Column(
                            children: snapshot.data!.docs.map((doc) {
                              return _buildDeployedSensorCard(doc).animate().fadeIn().slideX(begin: 0.1);
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE UI WIDGETS ---

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

  // Your original config card perfectly preserved
  Widget _buildSensorConfigCard({required String title, required TextEditingController controller, required GeoPoint? location, required VoidCallback onUpdateLocation}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_component, color: _cyanCustom, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Checkpoint Name / Area",
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("GPS Coordinates", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      location != null ? "${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}" : "Not Set",
                      style: TextStyle(color: location != null ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onUpdateLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text("Pin Here"),
              ),
            ],
          )
        ],
      ),
    );
  }

  // New list item for dynamically added sensors
  Widget _buildDeployedSensorCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['sensorName'] ?? 'Unknown Sensor';
    final area = data['checkpointArea'] ?? 'Unknown Area';
    final status = data['status'] ?? 'Pending Configuration';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.sensors, color: Colors.white70, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(area, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _dangerRed),
            onPressed: () => _deleteDocument('deployed_sensors', doc.id, false), // FALSE = standard deployed sensor
          )
        ],
      ),
    );
  }
}