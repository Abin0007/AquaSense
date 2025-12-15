// test/billing_info_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp
// Adjust the import path based on your project structure
import 'package:aquasense/models/billing_info.dart';

void main() {
  group('BillingInfo Model Tests', () {

    // --- Tests for currentFine ---     
    group('currentFine Calculation', () {
      final billDate = Timestamp.now(); // Base date for tests

      test('should return 0.0 fine if status is Paid', () {
        // Arrange
        final bill = BillingInfo(
          id: 'paid_bill',
          date: billDate, // Doesn't matter for this test
          amount: 100.0,
          reading: 50,
          status: 'Paid', // Key condition
        );

        // Act
        final fine = bill.currentFine;

        // Assert
        expect(fine, 0.0);
      });

      test('should return 0.0 fine if status is Due but within 10 days', () {
        // Arrange
        // Bill generated 5 days ago, due in 5 days
        final pastDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 5)));
        final bill = BillingInfo(
          id: 'due_not_late',
          date: pastDate, // Key condition
          amount: 100.0,
          reading: 50,
          status: 'Due', // Key condition
        );

        // Act
        final fine = bill.currentFine;

        // Assert
        expect(fine, 0.0);
      });

      test('should return correct fine if status is Due and past 10 days', () {
        // Arrange
        // Bill generated 15 days ago, due date was 5 days ago
        final lateDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 15)));
        final bill = BillingInfo(
          id: 'due_and_late',
          date: lateDate, // Key condition
          amount: 100.0,
          reading: 50,
          status: 'Due', // Key condition
        );

        // Act
        final fine = bill.currentFine;

        // Assert
        // Expecting 5 days late (15 days ago - 10 day grace period)
        expect(fine, 5.0);
      });

      test('should calculate fine correctly even if date is exactly 11 days ago', () {
        // Arrange
        final lateDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 11)));
        final bill = BillingInfo(
          id: 'due_just_late',
          date: lateDate,
          amount: 100.0,
          reading: 50,
          status: 'Due',
        );

        // Act
        final fine = bill.currentFine;

        // Assert
        expect(fine, 1.0); // 1 day late
      });
    });

    // --- Tests for wasPaidLate ---
    group('wasPaidLate Calculation', () {
      final billDate = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))); // Bill from 30 days ago

      test('should return false if bill is not paid (paidAt is null)', () {
        // Arrange
        final bill = BillingInfo(
          id: 'unpaid',
          date: billDate,
          amount: 100.0,
          reading: 50,
          status: 'Due',
          paidAt: null, // Key condition
        );

        // Act & Assert
        expect(bill.wasPaidLate, isFalse);
      });

      test('should return false if bill was paid within 10 days', () {
        // Arrange
        // Paid 5 days after bill date (within 10-day due period)
        final paidDate = Timestamp.fromDate(billDate.toDate().add(const Duration(days: 5)));
        final bill = BillingInfo(
          id: 'paid_on_time',
          date: billDate, // Key condition
          amount: 100.0,
          reading: 50,
          status: 'Paid',
          paidAt: paidDate, // Key condition
        );

        // Act & Assert
        expect(bill.wasPaidLate, isFalse);
      });

      test('should return true if bill was paid after 10 days', () {
        // Arrange
        // Paid 15 days after bill date (outside 10-day due period)
        final paidDate = Timestamp.fromDate(billDate.toDate().add(const Duration(days: 15)));
        final bill = BillingInfo(
          id: 'paid_late',
          date: billDate, // Key condition
          amount: 100.0,
          reading: 50,
          status: 'Paid',
          paidAt: paidDate, // Key condition
        );

        // Act & Assert
        expect(bill.wasPaidLate, isTrue);
      });

      test('should return true if bill was paid exactly on the 11th day', () {
        // Arrange
        final paidDate = Timestamp.fromDate(billDate.toDate().add(const Duration(days: 11)));
        final bill = BillingInfo(
          id: 'paid_just_late',
          date: billDate,
          amount: 100.0,
          reading: 50,
          status: 'Paid',
          paidAt: paidDate,
        );

        // Act & Assert
        expect(bill.wasPaidLate, isTrue);
      });
    });
  });
}