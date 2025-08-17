import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> getStates() async {
    try {
      QuerySnapshot snapshot = await _db.collection('locations').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      // Use debugPrint for development logs
      if (kDebugMode) {
        debugPrint("Error fetching states: $e");
      }
      return [];
    }
  }

  Future<List<String>> getDistricts(String state) async {
    try {
      DocumentSnapshot doc = await _db.collection('locations').doc(state).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return (data['districts'] as Map<String, dynamic>).keys.toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching districts for $state: $e");
      }
      return [];
    }
  }

  Future<List<String>> getWards(String state, String district) async {
    try {
      DocumentSnapshot doc = await _db.collection('locations').doc(state).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return List<String>.from((data['districts'] as Map<String, dynamic>)[district] ?? []);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching wards for $district: $e");
      }
      return [];
    }
  }
}