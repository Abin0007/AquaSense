import 'package:cloud_firestore/cloud_firestore.dart';

class WaterTank {
  final String id;
  final String tankName;
  final int level;
  final Timestamp lastUpdated;

  WaterTank({
    required this.id,
    required this.tankName,
    required this.level,
    required this.lastUpdated,
  });

  factory WaterTank.fromFirestore(DocumentSnapshot doc) {
    // Safety check: Provide an empty map if doc.data() is null to prevent crashes
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};

    return WaterTank(
      id: doc.id,
      tankName: data['tankName'] ?? 'Unnamed Tank',
      // SAFELY parse level: ensures it doesn't crash even if ESP32 sends a double or string format
      level: (data['level'] is num)
          ? (data['level'] as num).toInt()
          : int.tryParse(data['level']?.toString() ?? '0') ?? 0,
      // If the ESP32 doesn't send a timestamp, use the exact moment the stream is received
      lastUpdated: data['lastUpdated'] ?? Timestamp.now(),
    );
  }
}