import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pipeline_node_model.dart';
import '../models/leak_log_model.dart';

class IoTService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream live pipeline data for a specific ward
  Stream<PipelineNode?> streamWardPipelineData(String wardId) {
    return _db
        .collection('pipeline_nodes')
        .where('wardId', isEqualTo: wardId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return PipelineNode.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  // Stream active leaks for the Admin Dashboard
  Stream<List<LeakLog>> streamSystemActiveLeaks() {
    return _db
        .collection('leak_logs')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => LeakLog.fromMap(doc.data(), doc.id))
        .toList());
  }

  // --- NEW METHODS FOR EMERGENCY WORKFLOW ---

  // 1. Stream the current ACTIVE leak log for a ward (if any)
  Stream<LeakLog?> streamActiveLeakLog(String wardId) {
    return _db.collection('leak_logs')
        .where('wardId', isEqualTo: wardId)
        .where('status', isNotEqualTo: 'Resolved') // Only get active incidents
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return LeakLog.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  // 2. Start a new leak incident
  Future<void> initiateLeakProtocol(String wardId, double variance) async {
    await _db.collection('leak_logs').add({
      'wardId': wardId,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'Active',
      'severity': variance > 5.0 ? 'Critical' : 'Minor',
      'estimatedWaterLost': 0.0,
    });
  }

  // 3. Advance Workflow Steps
  Future<void> updateLeakWorkflow(String logId, Map<String, dynamic> data) async {
    await _db.collection('leak_logs').doc(logId).update(data);
  }
}