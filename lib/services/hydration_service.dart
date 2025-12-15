import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:aquasense/models/hydration_log.dart';

class HydrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;
  String get _todayDateId => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Get stream of today's hydration data
  Stream<HydrationLog?> getTodayHydrationStream() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('hydration_logs')
        .doc(_todayDateId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return HydrationLog.fromFirestore(doc);
      } else {
        // Return default empty log if no document exists yet
        return HydrationLog(
          dateId: _todayDateId,
          currentIntake: 0,
          dailyGoal: 2500, // Default goal
          history: [],
        );
      }
    });
  }

  // Add water intake
  Future<void> addIntake(int amount) async {
    final docRef = _db
        .collection('users')
        .doc(_userId)
        .collection('hydration_logs')
        .doc(_todayDateId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        // Create new doc for today
        transaction.set(docRef, {
          'currentIntake': amount,
          'dailyGoal': 2500, // Default goal
          'history': [
            {'amount': amount, 'time': Timestamp.now()}
          ]
        });
      } else {
        // Update existing
        int current = snapshot.data()!['currentIntake'] ?? 0;
        transaction.update(docRef, {
          'currentIntake': current + amount,
          'history': FieldValue.arrayUnion([
            {'amount': amount, 'time': Timestamp.now()}
          ])
        });
      }
    });
  }

  // Fetch last 7 days for the chart
  Future<List<HydrationLog>> getWeeklyHistory() async {
    final now = DateTime.now();
    List<HydrationLog> logs = [];

    // Fetch last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateId = DateFormat('yyyy-MM-dd').format(date);

      final doc = await _db
          .collection('users')
          .doc(_userId)
          .collection('hydration_logs')
          .doc(dateId)
          .get();

      if (doc.exists) {
        logs.add(HydrationLog.fromFirestore(doc));
      } else {
        logs.add(HydrationLog(
            dateId: dateId, currentIntake: 0, dailyGoal: 2500, history: []));
      }
    }
    return logs;
  }
}