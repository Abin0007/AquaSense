import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/services/billing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MeterInputWidget extends StatefulWidget {
  final int lastReading;
  final UserData citizen;
  final Function(String) onSuccess;
  final List<BillingInfo> unpaidBills;
  final List<BillingInfo> billingHistory;

  const MeterInputWidget({
    super.key,
    required this.lastReading,
    required this.onSuccess,
    required this.citizen,
    required this.unpaidBills,
    required this.billingHistory,
  });

  @override
  State<MeterInputWidget> createState() => _MeterInputWidgetState();
}

class _MeterInputWidgetState extends State<MeterInputWidget> {
  final _formKey = GlobalKey<FormState>();
  final _readingController = TextEditingController();
  final BillingService _billingService = BillingService();
  bool _isLoading = false;
  double? _calculatedAmount;
  int? _unitsConsumed;

  @override
  void initState() {
    super.initState();
    _readingController.addListener(_calculateBill);
  }

  @override
  void dispose() {
    _readingController.removeListener(_calculateBill);
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _calculateBill() async {
    if (_readingController.text.isNotEmpty) {
      final currentReading = int.tryParse(_readingController.text);
      if (currentReading != null && currentReading > widget.lastReading) {
        final units = currentReading - widget.lastReading;
        final pricePerUnit =
        await _billingService.getPricePerUnit(widget.citizen.wardId);
        const serviceCharge = 50.0;
        setState(() {
          _unitsConsumed = units;
          _calculatedAmount = (units * pricePerUnit) + serviceCharge;
        });
      } else {
        setState(() {
          _unitsConsumed = null;
          _calculatedAmount = null;
        });
      }
    } else {
      setState(() {
        _unitsConsumed = null;
        _calculatedAmount = null;
      });
    }
  }

  Future<void> _generateBill({bool isCashPayment = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentReading = int.parse(_readingController.text);
      final pricePerUnit =
      await _billingService.getPricePerUnit(widget.citizen.wardId);

      await _billingService.generateNewBill(
        citizen: widget.citizen,
        currentReading: currentReading,
        lastReading: widget.lastReading,
        pricePerUnit: pricePerUnit,
        isPaidByCash: isCashPayment,
      );

      widget.onSuccess(isCashPayment
          ? "Bill Generated & Marked as Paid!"
          : "Bill Generated Successfully!");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _payDuesInCash() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      for (var bill in widget.unpaidBills) {
        await _billingService.markBillAsPaidByCash(widget.citizen.uid, bill);
      }
      widget.onSuccess("All past dues have been marked as paid!");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _getAverageConsumption() {
    if (widget.billingHistory.length < 2) return 0.0;

    final sortedHistory = List<BillingInfo>.from(widget.billingHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    List<double> consumptionData = [];
    for (int i = 1; i < sortedHistory.length; i++) {
      final consumption = sortedHistory[i].reading - sortedHistory[i - 1].reading;
      consumptionData.add(consumption.toDouble());
    }
    if (consumptionData.isEmpty) return 0.0;
    return consumptionData.reduce((a, b) => a + b) / consumptionData.length;
  }

  @override
  Widget build(BuildContext context) {
    final totalDues = widget.unpaidBills.fold<double>(
        0, (sum, item) => sum + item.amount + item.currentFine);
    final averageConsumption = _getAverageConsumption();

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          children: [
            // --- MODIFIED LAYOUT ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Last Reading: ${widget.lastReading}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Avg. Consumption: ${averageConsumption.toStringAsFixed(1)} m³',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            // --- END MODIFICATION ---
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[800]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: TextFormField(
                controller: _readingController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '0000',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  counterText: '',
                ),
                maxLength: 6,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a reading.';
                  }
                  final reading = int.tryParse(value);
                  if (reading == null) {
                    return 'Invalid number.';
                  }
                  if (reading <= widget.lastReading) {
                    return 'Must be greater than last reading.';
                  }
                  return null;
                },
              ),
            ),
            if (_calculatedAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  children: [
                    Text(
                      'Units Consumed: $_unitsConsumed m³',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calculated Amount: ₹${_calculatedAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.cyanAccent)
            else ...[
              ElevatedButton(
                onPressed: _calculatedAmount == null ? null : () => _generateBill(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Generate & Notify User',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _calculatedAmount == null ? null : () => _generateBill(isCashPayment: true),
                icon: const Icon(Icons.money),
                label: const Text('Accept Cash & Generate Bill',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
            if (widget.unpaidBills.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 40),
              Text(
                'Past Dues: ₹${totalDues.toStringAsFixed(2)} (${widget.unpaidBills.length} bills)',
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _payDuesInCash,
                icon: const Icon(Icons.money),
                label: const Text('Accept Cash for Past Dues',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}