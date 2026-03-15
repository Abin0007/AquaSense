import 'package:cloud_firestore/cloud_firestore.dart';

class PipelineNode {
  final String nodeId;
  final String wardId;
  final double flowRateIn;
  final double flowRateOut;
  final String status; // "Normal", "Leak Detected", "Disconnected"
  final DateTime lastUpdated;

  PipelineNode({
    required this.nodeId,
    required this.wardId,
    required this.flowRateIn,
    required this.flowRateOut,
    required this.status,
    required this.lastUpdated,
  });

  factory PipelineNode.fromMap(Map<String, dynamic> map, String id) {
    return PipelineNode(
      nodeId: id,
      wardId: map['wardId'] ?? '',
      flowRateIn: (map['flowRateIn'] ?? 0).toDouble(),
      flowRateOut: (map['flowRateOut'] ?? 0).toDouble(),
      status: map['status'] ?? 'Disconnected',
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}