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
}