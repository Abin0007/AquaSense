import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:aquasense/models/cash_collection_model.dart';

class AdminCashSettlementsScreen extends StatefulWidget {
  const AdminCashSettlementsScreen({super.key});

  @override
  State<AdminCashSettlementsScreen> createState() => _AdminCashSettlementsScreenState();
}

class _AdminCashSettlementsScreenState extends State<AdminCashSettlementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to store user names and avoid redundant Firestore calls
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getUserName(String uid) async {
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name = doc.data()?['name'] ?? 'Unknown User';
      _userNameCache[uid] = name;
      return name;
    } catch (e) {
      return 'Unknown User';
    }
  }

  Future<void> _markAsSettledManually(String supervisorId, List<CashCollection> collections) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A32),
        title: const Text('Confirm Cash Receipt', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you confirming that you have received physical cash from this supervisor for these ${collections.length} transactions?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Received', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = _firestore.batch();
      for (var collection in collections) {
        final docRef = _firestore.collection('cash_collections').doc(collection.id);
        batch.update(docRef, {
          'status': 'SETTLED',
          'settlementPaymentId': 'MANUAL_CASH_RECEIPT',
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      Fluttertoast.showToast(msg: "Marked as settled successfully", backgroundColor: Colors.green);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('Cash Settlements Audit', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF152D4E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Pending Validation', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Settlement History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cash_collections')
          .where('status', isEqualTo: 'PENDING_SETTLEMENT')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyan));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('All supervisors have settled their cash.',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          );
        }

        // Group collections by supervisorId
        final Map<String, List<CashCollection>> groupedCollections = {};
        for (var doc in snapshot.data!.docs) {
          final collection = CashCollection.fromDoc(doc);
          groupedCollections.putIfAbsent(collection.supervisorId, () => []).add(collection);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedCollections.length,
          itemBuilder: (context, index) {
            final supervisorId = groupedCollections.keys.elementAt(index);
            final collections = groupedCollections[supervisorId]!;
            final totalAmount = collections.fold(0.0, (sum, item) => sum + item.amount);

            return Card(
              color: const Color(0xFF1E303A),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                collapsedIconColor: Colors.cyan,
                iconColor: Colors.cyanAccent,
                title: FutureBuilder<String>(
                  future: _getUserName(supervisorId),
                  builder: (context, nameSnapshot) {
                    return Text(
                      nameSnapshot.data ?? 'Loading...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    );
                  },
                ),
                subtitle: Text(
                  'Pending: ₹${totalAmount.toStringAsFixed(2)} (${collections.length} collections)',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                children: [
                  const Divider(color: Colors.white24),
                  ...collections.map((col) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, color: Colors.white54, size: 20),
                    title: FutureBuilder<String>(
                      future: _getUserName(col.citizenId),
                      builder: (context, citSnapshot) {
                        return Text('From: ${citSnapshot.data ?? 'Loading...'}',
                            style: const TextStyle(color: Colors.white70));
                      },
                    ),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(col.collectedAt.toDate()),
                        style: const TextStyle(color: Colors.white38)),
                    trailing: Text('₹${col.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark as Settled (Received Cash)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.withOpacity(0.2),
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyan),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _markAsSettledManually(supervisorId, collections),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('cash_collections')
          .where('status', isEqualTo: 'SETTLED')
          .orderBy('collectedAt', descending: true)
          .limit(50) // Limit to prevent massive reads
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyan));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No settlement history found.', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num).toDouble();
            final collectedAt = data['collectedAt'] as Timestamp;
            final supervisorId = data['supervisorId'] as String;
            final paymentId = data['settlementPaymentId'] ?? 'Unknown';

            return Card(
              color: const Color(0xFF1A2A32),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white),
                ),
                title: FutureBuilder<String>(
                  future: _getUserName(supervisorId),
                  builder: (context, snap) {
                    return Text(snap.data ?? 'Loading...', style: const TextStyle(color: Colors.white));
                  },
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MMM dd, yyyy - hh:mm a').format(collectedAt.toDate()),
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('Ref: $paymentId', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
                trailing: Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            );
          },
        );
      },
    );
  }
}