import 'package:flutter/material.dart';
import '../../../models/pipeline_node_model.dart';
import '../../../services/iot_service.dart';

class PipelineHealthScreen extends StatelessWidget {
  final String wardId;
  const PipelineHealthScreen({Key? key, required this.wardId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ioTService = IoTService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Pipeline Health'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<PipelineNode?>(
        stream: ioTService.streamWardPipelineData(wardId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No IoT Sensors deployed in this ward yet."));
          }

          final node = snapshot.data!;
          final isLeaking = node.status == 'Leak Detected';

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isLeaking ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isLeaking ? Colors.red : Colors.green),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isLeaking ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isLeaking ? Colors.redAccent : Colors.greenAccent,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        node.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isLeaking ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text("Differential Flow Analysis", style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                _buildFlowCard("Flow In (Sensor 1)", "${node.flowRateIn} L/min", Colors.cyan),
                const SizedBox(height: 16),
                _buildFlowCard("Flow Out (Sensor 2)", "${node.flowRateOut} L/min", isLeaking ? Colors.redAccent : Colors.cyan),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlowCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}