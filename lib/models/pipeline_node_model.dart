import 'package:cloud_firestore/cloud_firestore.dart';

class PipelineNode {
  final String nodeId;
  final String wardId;
  final double flowRateIn;
  final double flowRateOut;
  final String status;
  final DateTime lastUpdated;

  // --- NEW: Sensor Location Data ---
  final GeoPoint? sensor1Location;
  final String sensor1Address;
  final GeoPoint? sensor2Location;
  final String sensor2Address;

  PipelineNode({
    required this.nodeId,
    required this.wardId,
    required this.flowRateIn,
    required this.flowRateOut,
    required this.status,
    required this.lastUpdated,
    this.sensor1Location,
    this.sensor1Address = 'Main Ingress Point',
    this.sensor2Location,
    this.sensor2Address = 'Egress Alpha',
  });

  factory PipelineNode.fromMap(Map<String, dynamic> map, String id) {
    return PipelineNode(
      nodeId: id,
      wardId: map['wardId'] ?? '',
      // UPDATED: Checks for both your old dummy key ('flowRateIn') and the new ESP32 key ('flowInRate')
      flowRateIn: (map['flowInRate'] ?? map['flowRateIn'] ?? 0).toDouble(),
      flowRateOut: (map['flowOutRate'] ?? map['flowRateOut'] ?? 0).toDouble(),
      status: map['status'] ?? 'Disconnected',
      // UPDATED: If the ESP32 doesn't send a timestamp, use the exact moment the stream is received
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sensor1Location: map['sensor1Location'] as GeoPoint?,
      sensor1Address: map['sensor1Address'] ?? 'Main Ingress Point',
      sensor2Location: map['sensor2Location'] as GeoPoint?,
      sensor2Address: map['sensor2Address'] ?? 'Egress Alpha',
    );
  }
}