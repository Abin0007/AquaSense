import 'package:aquasense/models/hydration_log.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/services/hydration_service.dart';
import 'package:aquasense/screens/health/hydration_setup_screen.dart'; // Import setup screen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  final HydrationService _service = HydrationService();

  // Theme Colors - Matching your "Hydro-Futurism" Palette
  final Color bgDark = const Color(0xFF0F2027);
  final Color cardColor = const Color(0xFF203A43);
  final Color accentCyan = const Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Hydration Tracker",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)
        ),
        centerTitle: true,
        actions: [
          // NEW: Settings Button
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HydrationSetupScreen()));
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgDark, const Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<HydrationLog?>(
            stream: _service.getTodayHydrationStream(),
            builder: (context, snapshot) {

              // Handle loading/empty states gracefully
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
              }

              final log = snapshot.data;
              final current = log?.currentIntake ?? 0;
              // Goal now comes from the service which should ideally check UserData,
              // but for now, we use the log's goal which defaults to 2500 if new.
              final goal = log?.dailyGoal ?? 2500;

              // Calculate progress (0.0 to 1.0)
              double progress = (goal > 0) ? (current / goal).clamp(0.0, 1.0) : 0.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // --- Main Progress Circle ---
                    SizedBox(
                      height: 280,
                      width: 280,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Ring
                          CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 20,
                            color: Colors.white.withOpacity(0.05),
                          ),
                          // Animated Value Ring
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: 1.5.seconds,
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => CircularProgressIndicator(
                              value: value,
                              strokeWidth: 20,
                              valueColor: AlwaysStoppedAnimation(accentCyan),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          // Inner Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.water_drop, color: accentCyan, size: 48)
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .scaleXY(end: 1.1, duration: 2.seconds),
                              const SizedBox(height: 10),
                              Text(
                                "$current",
                                style: GoogleFonts.bebasNeue(
                                    fontSize: 64,
                                    color: Colors.white
                                ),
                              ),
                              Text(
                                "/ $goal ml",
                                style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 16
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),

                    const SizedBox(height: 40),

                    // --- Quick Add Buttons ---
                    Text("Quick Log",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600
                        )
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildGlassButton(100, "Sip"),
                        _buildGlassButton(250, "Glass"),
                        _buildGlassButton(500, "Bottle"),
                      ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.5),
                    ),

                    const SizedBox(height: 40),

                    // --- Weekly Trends Chart ---
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Weekly History",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600
                              )
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: FutureBuilder<List<HydrationLog>>(
                              future: _service.getWeeklyHistory(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
                                }
                                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Center(child: Text("No history available", style: TextStyle(color: Colors.white38)));
                                }

                                final logs = snapshot.data!;

                                return BarChart(
                                  BarChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >= 0 && value.toInt() < logs.length) {
                                              // Parse YYYY-MM-DD to Day Name
                                              try {
                                                final date = DateFormat('yyyy-MM-dd').parse(logs[value.toInt()].dateId);
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 8.0),
                                                  child: Text(
                                                    DateFormat('E').format(date)[0], // M, T, W...
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  ),
                                                );
                                              } catch (e) {
                                                return const Text('');
                                              }
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: logs.asMap().entries.map((e) {
                                      final index = e.key;
                                      final log = e.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: log.currentIntake.toDouble(),
                                            color: accentCyan,
                                            width: 12,
                                            backDrawRodData: BackgroundBarChartRodData(
                                              show: true,
                                              toY: (log.dailyGoal > 0 ? log.dailyGoal.toDouble() : 2500.0) + 500, // Dynamic max scale
                                              color: Colors.white.withOpacity(0.05),
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(int amount, String label) {
    return InkWell(
      onTap: () async {
        try {
          await _service.addIntake(amount);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Added $amount ml", style: GoogleFonts.poppins()),
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.8),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                )
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent)
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, color: accentCyan, size: 28),
            const SizedBox(height: 8),
            Text("+$amount", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("ml", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
