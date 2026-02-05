import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BillingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<double> getPricePerUnit(String wardId) async {
    try {
      final doc = await _db.collection('ward_pricing').doc(wardId).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['pricePerUnit'] as num).toDouble();
      }
      // Return a default or base price if no specific price is set for the ward
      return 8.0;
    } catch (e) {
      debugPrint("Error fetching price for ward $wardId: $e");
      return 8.0; // Fallback to default price on error
    }
  }

  Future<BillingInfo?> getLastBill(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('billingHistory')
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return BillingInfo.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching last bill for user $userId: $e");
      return null;
    }
  }

  Future<void> generateNewBill({
    required UserData citizen,
    required int currentReading,
    required int lastReading,
    required double pricePerUnit,
    bool isPaidByCash = false,
  }) async {
    final supervisor = FirebaseAuth.instance.currentUser;
    if (supervisor == null) throw Exception("Supervisor not logged in.");

    final unitsConsumed = currentReading - lastReading;
    if (unitsConsumed < 0) {
      throw Exception("Current reading cannot be less than the last reading.");
    }

    const double serviceCharge = 50.0;
    final amount = (unitsConsumed * pricePerUnit) + serviceCharge;

    String? paymentId;
    if (isPaidByCash) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Using a more robust and unique ID format
      paymentId = 'CASH-${supervisor.uid.substring(0, 5)}-$timestamp';
    }

    // Reference for the new bill document in the user's sub-collection
    final newBillRef = _db
        .collection('users')
        .doc(citizen.uid)
        .collection('billingHistory')
        .doc();

    final newBillData = {
      'date': Timestamp.now(),
      'amount': amount,
      'reading': currentReading,
      'status': isPaidByCash ? 'Paid' : 'Due',
      'paidAt': isPaidByCash ? Timestamp.now() : null,
      'paymentId': paymentId,
      'generatedBy': supervisor.uid,
      'fineAmount': 0.0, // Initial fine is always 0
    };

    try {
      final batch = _db.batch();

      // Set the new bill data
      batch.set(newBillRef, newBillData);

      // If it's a cash payment, also create a record in cash_collections
      if (isPaidByCash) {
        final cashCollectionRef = _db.collection('cash_collections').doc();
        final cashCollectionData = {
          'supervisorId': supervisor.uid,
          'citizenId': citizen.uid,
          'billId': newBillRef.id,
          'amount': amount,
          'collectedAt': Timestamp.now(),
          'status': 'PENDING_SETTLEMENT',
        };

        // --- ADDED FOR DEBUGGING ---
        debugPrint("Attempting to write to cash_collections with data: $cashCollectionData");
        // -------------------------

        batch.set(cashCollectionRef, cashCollectionData);
      }

      // Commit all writes at once
      await batch.commit();

    } catch (e) {
      debugPrint("Error generating new bill: $e");
      // Throw a more user-friendly error message
      throw Exception("Failed to generate and save the new bill.");
    }
  }

  Future<List<BillingInfo>> getUnpaidBills(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('billingHistory')
          .where('status', isEqualTo: 'Due')
          .get();
      return querySnapshot.docs
          .map((doc) => BillingInfo.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Error fetching unpaid bills for user $userId: $e");
      return [];
    }
  }

  Future<void> markBillAsPaidByCash(String userId, BillingInfo bill) async {
    final supervisor = FirebaseAuth.instance.currentUser;
    if (supervisor == null) throw Exception("Supervisor not logged in.");

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final professionalPaymentId =
          'CASH-DUES-${supervisor.uid.substring(0, 5)}-$timestamp';
      final totalAmountPaid = bill.amount + bill.currentFine;

      final billRef = _db
          .collection('users')
          .doc(userId)
          .collection('billingHistory')
          .doc(bill.id);
      final cashCollectionRef = _db.collection('cash_collections').doc();

      final batch = _db.batch();

      // Update the existing bill
      batch.update(billRef, {
        'status': 'Paid',
        'paidAt': Timestamp.now(),
        'paymentId': professionalPaymentId,
        'fineAmount': bill.currentFine, // Store the calculated fine at time of payment
      });

      // Create the new cash collection record
      batch.set(cashCollectionRef, {
        'supervisorId': supervisor.uid,
        'citizenId': userId,
        'billId': bill.id,
        'amount': totalAmountPaid,
        'collectedAt': Timestamp.now(),
        'status': 'PENDING_SETTLEMENT',
      });

      await batch.commit();
    } catch (e) {
      debugPrint("Error marking bill as paid: $e");
      throw Exception(
          "Failed to update bill status. Check Firestore security rules. Original error: $e");
    }
  }
}
