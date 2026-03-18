import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GlobalIoTDashboardScreen extends StatefulWidget {
  const GlobalIoTDashboardScreen({super.key});

  @override
  State<GlobalIoTDashboardScreen> createState() => _GlobalIoTDashboardScreenState();
}

class _GlobalIoTDashboardScreenState extends State<GlobalIoTDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Global Live IoT Health', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF152D4E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.cyanAccent),
            tooltip: 'System Audit Info',
            onPressed: () => _showAuditInfoDialog(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('locations').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No Wards Found. Please add infrastructure locations first.',
                  style: TextStyle(color: Colors.white54)),
            );
          }

          final wards = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: wards.length,
            itemBuilder: (context, index) {
              final wardDoc = wards[index];
              final wardName = wardDoc['name'] ?? 'Unnamed Ward';
              final wardId = wardDoc.id;

              return Card(
                color: const Color(0xFF1A2A32),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: ExpansionTile(
                  initiallyExpanded: index == 0, // Keep the first one open
                  iconColor: Colors.cyanAccent,
                  collapsedIconColor: Colors.cyan,
                  title: Text(
                    wardName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Ward ID: $wardId', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  children: [
                    Container(
                      color: const Color(0xFF12222A),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🚰 LIVE TANK LEVELS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _buildTankDataStream(wardId),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          const Text('🌊 PIPELINE HEALTH (FLOW RATES)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          const SizedBox(height: 8),
                          _buildPipelineDataStream(wardId),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- SUB-WIDGET: TANK STREAM (UPDATED) ---
  Widget _buildTankDataStream(String wardId) {
    // FIX: Fetch the exact document matching the wardId (like the Supervisor app does)
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('water_tanks').doc(wardId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(color: Colors.blueAccent);
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('No active tanks deployed in this ward.', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final level = (data['level'] as num?)?.toDouble() ?? 0.0;
        final lastUpdated = data['lastUpdated'] as Timestamp?;
        final isLow = level < 20.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: level / 100,
                    backgroundColor: Colors.white10,
                    color: isLow ? Colors.redAccent : Colors.blueAccent,
                    strokeWidth: 6,
                  ),
                  Text('${level.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['tankName'] ?? 'Main Tank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Updated: ${lastUpdated != null ? DateFormat('hh:mm:ss a').format(lastUpdated.toDate()) : 'N/A'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              if (isLow)
                const Icon(Icons.warning, color: Colors.redAccent, size: 20)
            ],
          ),
        );
      },
    );
  }

  // --- SUB-WIDGET: PIPELINE STREAM ---
  Widget _buildPipelineDataStream(String wardId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('pipeline_nodes').where('wardId', isEqualTo: wardId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(color: Colors.cyanAccent);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No pipeline sensors deployed in this ward.', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic));
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final flowIn = (data['flowRateIn'] as num?)?.toDouble() ?? 0.0;
            final flowOut = (data['flowRateOut'] as num?)?.toDouble() ?? 0.0;
            final status = data['status'] ?? 'Normal';
            final isLeak = status == 'Leak_Detected' || (flowIn - flowOut).abs() > 5.0; // Math failsafe

            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLeak ? Colors.redAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isLeak ? Colors.redAccent : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(isLeak ? Icons.broken_image : Icons.route, color: isLeak ? Colors.redAccent : Colors.cyanAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['nodeName'] ?? 'Pipeline Segment', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward, color: Colors.blueAccent, size: 14),
                            Text(' In: ${flowIn.toStringAsFixed(1)} L/s  ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const Icon(Icons.arrow_upward, color: Colors.orangeAccent, size: 14),
                            Text(' Out: ${flowOut.toStringAsFixed(1)} L/s', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(isLeak ? 'LEAK' : 'OK', style: TextStyle(color: isLeak ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: isLeak ? Colors.red : Colors.greenAccent,
                    visualDensity: VisualDensity.compact,
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAuditInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A32),
        title: const Text('Master Sensor Audit', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This dashboard reads directly from the deployed IoT sensors across all wards.\n\n'
              '• Tank Levels turn RED when dropping below 20%.\n'
              '• Pipeline Nodes automatically flag a LEAK if the Flow Out rate is significantly lower than the Flow In rate.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
          )
        ],
      ),
    );
  }
}