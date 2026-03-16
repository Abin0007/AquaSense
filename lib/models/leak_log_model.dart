import 'package:cloud_firestore/cloud_firestore.dart';

class LeakLog {
  final String logId;
  final String wardId;
  final double estimatedWaterLost;
  final String severity;
  final String status; // "Active", "Valves_Closed", "Investigating", "Resolved"

  // --- NEW: Timeline & Proof Data ---
  final DateTime startTime;
  final DateTime? valvesShutdownAt;
  final DateTime? arrivedAt;
  final String? arrivedPhotoUrl;
  final GeoPoint? arrivedLocation;
  final DateTime? resolvedAt;
  final String? resolvedPhotoUrl;
  final GeoPoint? resolvedLocation;

  LeakLog({
    required this.logId,
    required this.wardId,
    required this.estimatedWaterLost,
    required this.severity,
    required this.status,
    required this.startTime,
    this.valvesShutdownAt,
    this.arrivedAt,
    this.arrivedPhotoUrl,
    this.arrivedLocation,
    this.resolvedAt,
    this.resolvedPhotoUrl,
    this.resolvedLocation,
  });

  factory LeakLog.fromMap(Map<String, dynamic> map, String id) {
    return LeakLog(
      logId: id,
      wardId: map['wardId'] ?? '',
      estimatedWaterLost: (map['estimatedWaterLost'] ?? 0).toDouble(),
      severity: map['severity'] ?? 'Minor',
      status: map['status'] ?? 'Active',
      startTime: (map['startTime'] as Timestamp).toDate(),
      valvesShutdownAt: map['valvesShutdownAt'] != null ? (map['valvesShutdownAt'] as Timestamp).toDate() : null,
      arrivedAt: map['arrivedAt'] != null ? (map['arrivedAt'] as Timestamp).toDate() : null,
      arrivedPhotoUrl: map['arrivedPhotoUrl'],
      arrivedLocation: map['arrivedLocation'] as GeoPoint?,
      resolvedAt: map['resolvedAt'] != null ? (map['resolvedAt'] as Timestamp).toDate() : null,
      resolvedPhotoUrl: map['resolvedPhotoUrl'],
      resolvedLocation: map['resolvedLocation'] as GeoPoint?,
    );
  }
}