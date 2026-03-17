import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WardPricingConfigScreen extends StatefulWidget {
  const WardPricingConfigScreen({super.key});

  @override
  State<WardPricingConfigScreen> createState() => _WardPricingConfigScreenState();
}

class _WardPricingConfigScreenState extends State<WardPricingConfigScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to show the update dialog
  void _showUpdatePriceDialog(BuildContext context, String wardId, String wardName, num currentPrice) {
    final TextEditingController priceController = TextEditingController(text: currentPrice.toString());
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2A32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Update Price: $wardName',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set the new price per liter for this ward. This will affect all future billing calculations.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Price per Liter (₹)',
                    labelStyle: const TextStyle(color: Colors.cyan),
                    prefixIcon: const Icon(Icons.currency_rupee, color: Colors.cyan),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.cyan, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a price';
                    if (double.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newPrice = double.parse(priceController.text.trim());
                  await _updateWardPrice(wardId, newPrice);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Function to update Firestore
  Future<void> _updateWardPrice(String wardId, num newPrice) async {
    try {
      await _firestore.collection('ward_pricing').doc(wardId).set({
        'pricePerLiter': newPrice,
        'lastUpdated': FieldValue.serverTimestamp(),
        // Note: wardName should ideally be set when the ward is first created
      }, SetOptions(merge: true));

      Fluttertoast.showToast(
        msg: "Pricing updated successfully!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to update pricing: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027), // App-wide background color
      appBar: AppBar(
        title: const Text('Ward Pricing Config', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ward_pricing').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyan));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data.', style: TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No wards configured yet.\nAdd wards in Location Management.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final wards = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: wards.length,
            itemBuilder: (context, index) {
              final data = wards[index].data() as Map<String, dynamic>;
              final wardId = wards[index].id;
              final wardName = data['wardName'] ?? 'Ward $wardId';
              final pricePerLiter = data['pricePerLiter'] ?? 0.0;
              final Timestamp? lastUpdatedTs = data['lastUpdated'];

              String lastUpdatedStr = 'Never updated';
              if (lastUpdatedTs != null) {
                lastUpdatedStr = DateFormat('MMM dd, yyyy - hh:mm a').format(lastUpdatedTs.toDate());
              }

              return Card(
                color: const Color(0xFF1E303A),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Ward Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wardName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: $wardId',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Last Updated: $lastUpdatedStr',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Pricing & Edit Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹$pricePerLiter / L',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan.withOpacity(0.2),
                              foregroundColor: Colors.cyanAccent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.cyan, width: 1),
                              ),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit Price'),
                            onPressed: () => _showUpdatePriceDialog(context, wardId, wardName, pricePerLiter),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}