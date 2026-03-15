import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/leak_log_model.dart';
import '../../../services/iot_service.dart';

class InfrastructureReportsScreen extends StatelessWidget {
  const InfrastructureReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure Leak Reports'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<LeakLog>>(
        stream: IoTService().streamSystemActiveLeaks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No incidents reported. System is healthy."));
          }

          final logs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isActive = log.status == 'Active';

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ward ID: ${log.wardId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(log.status),
                            backgroundColor: isActive ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            side: BorderSide(color: isActive ? Colors.redAccent : Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text("Started: ${DateFormat('MMM dd, yyyy - hh:mm a').format(log.startTime)}", style: const TextStyle(color: Colors.grey)),
                      if (!isActive && log.resolvedTime != null)
                        Text("Resolved: ${DateFormat('MMM dd, yyyy - hh:mm a').format(log.resolvedTime!)}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.water_drop, color: Colors.cyan, size: 16),
                          const SizedBox(width: 8),
                          Text("Est. Water Lost: ${log.estimatedWaterLost} Liters", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
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