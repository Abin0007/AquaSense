import 'package:aquasense/models/cash_collection_model.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/services/payment_service.dart';
import 'package:aquasense/utils/helper_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:lottie/lottie.dart';

class SettlePaymentsScreen extends StatefulWidget {
  const SettlePaymentsScreen({super.key});

  @override
  State<SettlePaymentsScreen> createState() => _SettlePaymentsScreenState();
}

class _SettlePaymentsScreenState extends State<SettlePaymentsScreen> {
  late PaymentService _paymentService;
  late Stream<List<CashCollection>> _collectionsStream;
  List<CashCollection> _pendingCollections = [];
  double _totalCashCollected = 0.0;
  bool _isLoading = false;
  final String? supervisorId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _setupStream();
    _paymentService = PaymentService(
      onPaymentSuccess: _handlePaymentSuccess,
      onPaymentFailure: _handlePaymentError,
      onExternalWallet: (response) {},
    );
  }

  void _setupStream() {
    if (supervisorId == null) {
      _collectionsStream = Stream.value([]);
      return;
    }
    _collectionsStream = FirebaseFirestore.instance
        .collection('cash_collections')
        .where('supervisorId', isEqualTo: supervisorId)
        .where('status', isEqualTo: 'PENDING_SETTLEMENT')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CashCollection.fromDoc(doc)).toList());
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("Settlement Successful: ${response.paymentId}");

    final batch = FirebaseFirestore.instance.batch();
    for (final collection in _pendingCollections) {
      final docRef = FirebaseFirestore.instance.collection('cash_collections').doc(collection.id);
      batch.update(docRef, {'status': 'SETTLED', 'settlementPaymentId': response.paymentId});
    }
    await batch.commit();

    if (mounted) {
      _showSuccessDialog();
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Settlement Failed: ${response.code} - ${response.message}");
    if (mounted) {
      HelperFunctions.showError(context, "Payment Failed: ${response.message}");
      setState(() => _isLoading = false);
    }
  }

  void _initiatePaymentToAdmin(UserData supervisorData) {
    if (_totalCashCollected <= 0) {
      HelperFunctions.showSnackBar(context, "No amount to transfer.", color: Colors.blue);
      return;
    }
    setState(() => _isLoading = true);
    _paymentService.openCheckout(
      amount: _totalCashCollected,
      description: 'Cash Settlement by ${supervisorData.name}',
      userEmail: supervisorData.email,
      userPhone: supervisorData.phoneNumber ?? '',
      userName: supervisorData.name,
    );
  }

  void _showSuccessDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Transfer Successful!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Settle Cash Payments'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: StreamBuilder<List<CashCollection>>(
        stream: _collectionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            _totalCashCollected = 0.0;
            _pendingCollections = [];
            return _buildContent(null, []);
          }
          _pendingCollections = snapshot.data!;
          _totalCashCollected = _pendingCollections.fold(0.0, (total, item) => total + item.amount);

          return _buildContent(FirebaseAuth.instance.currentUser, _pendingCollections);
        },
      ),
    );
  }

  Widget _buildContent(User? supervisor, List<CashCollection> collections) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.purpleAccent),
              const SizedBox(height: 16),
              const Text(
                'Total Cash in Hand',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${_totalCashCollected.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: supervisor == null ? null : () async {
                  final supervisorDoc = await FirebaseFirestore.instance.collection('users').doc(supervisor.uid).get();
                  if (supervisorDoc.exists) {
                    _initiatePaymentToAdmin(UserData.fromFirestore(supervisorDoc));
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Transfer Collected Cash', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Recent Cash Collections", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: collections.isEmpty
              ? const Center(child: Text("No cash collections to settle.", style: TextStyle(color: Colors.white70)))
              : ListView.builder(
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return ListTile(
                leading: const Icon(Icons.person, color: Colors.cyanAccent),
                title: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(collection.citizenId).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        return Text(userSnapshot.data!.get('name') ?? 'Unknown User');
                      }
                      return const Text("Loading user...");
                    }
                ),
                subtitle: Text(DateFormat('d MMM y, h:mm a').format(collection.collectedAt.toDate())),
                trailing: Text('₹${collection.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
            },
          ),
        )
      ],
    );
  }
}