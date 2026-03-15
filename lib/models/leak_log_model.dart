import 'package:cloud_firestore/cloud_firestore.dart';

class LeakLog {
  final String logId;
  final String wardId;
  final DateTime startTime;
  final DateTime? resolvedTime;
  final double estimatedWaterLost;
  final String severity; // "Minor", "Critical"
  final String status; // "Active", "Resolved"

  LeakLog({
    required this.logId,
    required this.wardId,
    required this.startTime,
    this.resolvedTime,
    required this.estimatedWaterLost,
    required this.severity,
    required this.status,
  });

  factory LeakLog.fromMap(Map<String, dynamic> map, String id) {
    return LeakLog(
      logId: id,
      wardId: map['wardId'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      resolvedTime: map['resolvedTime'] != null ? (map['resolvedTime'] as Timestamp).toDate() : null,
      estimatedWaterLost: (map['estimatedWaterLost'] ?? 0).toDouble(),
      severity: map['severity'] ?? 'Minor',
      status: map['status'] ?? 'Active',
    );
  }
}