import 'package:cloud_firestore/cloud_firestore.dart';

class HydrationLog {
  final String dateId; // Format: YYYY-MM-DD
  final int currentIntake;
  final int dailyGoal;
  final List<Map<String, dynamic>> history; // [{time: Timestamp, amount: 200}]

  HydrationLog({
    required this.dateId,
    required this.currentIntake,
    required this.dailyGoal,
    required this.history,
  });

  factory HydrationLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return HydrationLog(
      dateId: doc.id,
      currentIntake: data['currentIntake'] ?? 0,
      dailyGoal: data['dailyGoal'] ?? 2500,
      history: List<Map<String, dynamic>>.from(data['history'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentIntake': currentIntake,
      'dailyGoal': dailyGoal,
      'history': history,
    };
  }
}