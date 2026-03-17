import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class HydrationSetupScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const HydrationSetupScreen({super.key, this.onCompleted});

  @override
  State<HydrationSetupScreen> createState() => _HydrationSetupScreenState();
}

class _HydrationSetupScreenState extends State<HydrationSetupScreen> {
  String _selectedGender = 'Male';
  double _weight = 75.0;
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);

  bool _isSaving = false;

  // Calculates daily water goal based on weight (approx 35ml per kg)
  int get _calculatedGoal => (_weight * 35).round();

  Future<void> _saveGoal() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Format times to string for storage
        final wakeStr = "${_wakeUpTime.hour.toString().padLeft(2, '0')}:${_wakeUpTime.minute.toString().padLeft(2, '0')}";
        final bedStr = "${_bedTime.hour.toString().padLeft(2, '0')}:${_bedTime.minute.toString().padLeft(2, '0')}";

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'gender': _selectedGender,
          'weight': _weight.toInt(),
          'wakeUpTime': wakeStr,
          'bedTime': bedStr,
          'hydrationGoal': _calculatedGoal,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Goal updated successfully!"), backgroundColor: Colors.green)
          );
          if (widget.onCompleted != null) {
            widget.onCompleted!();
          } else {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(bool isWakeUp) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isWakeUp ? _wakeUpTime : _bedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF),
              onPrimary: Colors.black,
              surface: Color(0xFF2C5364),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isWakeUp) {
          _wakeUpTime = picked;
        } else {
          _bedTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Text("Setup", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Personalize",
                style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2
                )
            ).animate().fadeIn().slideY(begin: 0.2),
            Text("Your Goal",
                style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                    height: 1.2
                )
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 30),

            // Gender Selection
            _buildSectionHeader("GENDER"),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildGenderCard("Male", Icons.male, _selectedGender == "Male"),
                const SizedBox(width: 16),
                _buildGenderCard("Female", Icons.female, _selectedGender == "Female"),
              ],
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 30),

            // Weight Selection
            _buildSectionHeader("WEIGHT"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${_weight.toInt()}",
                        style: GoogleFonts.bebasNeue(fontSize: 48, color: const Color(0xFF00E5FF)),
                      ),
                      Text(" kg", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF00E5FF),
                      inactiveTrackColor: Colors.white10,
                      thumbColor: const Color(0xFF00E5FF),
                      overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: _weight,
                      min: 30,
                      max: 150,
                      divisions: 120,
                      onChanged: (val) => setState(() => _weight = val),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn(),

            const SizedBox(height: 30),

            // Time Selection
            _buildSectionHeader("ACTIVE HOURS"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTimePicker("WAKE UP", _wakeUpTime, Icons.wb_sunny_outlined, true)),
                  Container(width: 1, height: 40, color: Colors.white10),
                  Expanded(child: _buildTimePicker("BEDTIME", _bedTime, Icons.nightlight_round, false)),
                ],
              ),
            ).animate(delay: 400.ms).fadeIn(),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F2027),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Daily Target", style: GoogleFonts.poppins(color: Colors.white70)),
                Row(
                  children: [
                    Text("$_calculatedGoal", style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(" ml", style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("START TRACKING", style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: 8),
                    const Icon(Icons.water_drop)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white54,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildGenderCard(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = label),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00E5FF) : Colors.white70, size: 32),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, IconData icon, bool isWakeUp) {
    return GestureDetector(
      onTap: () => _pickTime(isWakeUp),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time.format(context),
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

