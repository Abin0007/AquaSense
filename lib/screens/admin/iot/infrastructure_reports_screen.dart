import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/leak_log_model.dart';
import '../../../services/iot_service.dart';

// ✅ IMPORT THE SUPERVISOR'S INCIDENT DETAIL SCREEN
import '../../supervisor/iot/incident_detail_screen.dart';

class InfrastructureReportsScreen extends StatelessWidget {
  const InfrastructureReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027), // Matching app theme
      appBar: AppBar(
        title: const Text('Infrastructure Leak Reports', style: TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: const Color(0xFF152D4E), // Matching admin app bar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<LeakLog>>(
        stream: IoTService().streamSystemActiveLeaks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No incidents reported. System is healthy.", style: TextStyle(color: Colors.white70)));
          }

          final logs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];

              // --- CORRECTED BADGE LOGIC ---
              // It is ongoing (Red) UNLESS it is fully 'Resolved' (Green)
              final isOngoing = log.status != 'Resolved';

              // Calculate Duration
              final duration = log.resolvedAt?.difference(log.startTime);

              final durationText = duration != null
                  ? "${duration.inHours}h ${duration.inMinutes.remainder(60)}m to resolve"
                  : "Ongoing...";

              return Card(
                color: Colors.white.withValues(alpha: 0.05),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                // ✅ WRAPPED IN INKWELL TO ALLOW TAPPING
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    // ✅ ROUTE TO THE DETAIL SCREEN
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncidentDetailScreen(log: log),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Ward ID: ${log.wardId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            Chip(
                              label: Text(
                                  log.status.replaceAll('_', ' '),
                                  style: TextStyle(
                                      color: isOngoing ? Colors.redAccent : Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold
                                  )
                              ),
                              backgroundColor: isOngoing ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
                              side: BorderSide(color: isOngoing ? Colors.redAccent : Colors.greenAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text("Started: ${DateFormat('MMM dd, yyyy - hh:mm a').format(log.startTime)}", style: const TextStyle(color: Colors.white54)),

                        if (!isOngoing && log.resolvedAt != null)
                          Text("Resolved: ${DateFormat('MMM dd, yyyy - hh:mm a').format(log.resolvedAt!)}", style: const TextStyle(color: Colors.white54)),

                        const SizedBox(height: 12),

                        // Duration display
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 16),
                            const SizedBox(width: 8),
                            Text("Resolution Time: $durationText", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent, fontSize: 13)),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 16),
                            const SizedBox(width: 8),
                            Text("Est. Water Lost: ${log.estimatedWaterLost} Liters", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 13)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}