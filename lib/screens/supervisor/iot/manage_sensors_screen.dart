import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/pipeline_node_model.dart';

class ManageSensorsScreen extends StatefulWidget {
  final String wardId;
  const ManageSensorsScreen({Key? key, required this.wardId}) : super(key: key);

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
      final snapshot = await FirebaseFirestore.instance
          .collection('pipeline_nodes')
          .where('wardId', isEqualTo: widget.wardId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final node = PipelineNode.fromMap(doc.data(), doc.id);
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
      setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sensor locations updated successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Manage Checkpoints', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FF)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Configure physical locations for the flow sensors in this ward. This data is critical for emergency routing.", style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 32),

            _buildSensorConfigCard(
              title: "Sensor 1 (Flow In)",
              controller: _sensor1AddressCtrl,
              location: _sensor1Loc,
              onUpdateLocation: () async {
                final loc = await _getLiveLocation();
                if (loc != null) setState(() => _sensor1Loc = loc);
              },
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            _buildSensorConfigCard(
              title: "Sensor 2 (Flow Out)",
              controller: _sensor2AddressCtrl,
              location: _sensor2Loc,
              onUpdateLocation: () async {
                final loc = await _getLiveLocation();
                if (loc != null) setState(() => _sensor2Loc = loc);
              },
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F2FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saveSensorData,
              child: const Text("SAVE CONFIGURATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorConfigCard({required String title, required TextEditingController controller, required GeoPoint? location, required VoidCallback onUpdateLocation}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_component, color: Color(0xFF00F2FF), size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Name/Address Input
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

          // GPS Coordinates Display & Update Button
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
                  backgroundColor: Colors.white.withOpacity(0.1),
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
}