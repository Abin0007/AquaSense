import 'package:aquasense/models/hydration_log.dart';
import 'package:aquasense/services/hydration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class HydrationCard extends StatelessWidget {
  final VoidCallback onTap;

  const HydrationCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HydrationLog?>(
      stream: HydrationService().getTodayHydrationStream(),
      builder: (context, snapshot) {
        final log = snapshot.data;
        final current = log?.currentIntake ?? 0;
        final goal = log?.dailyGoal ?? 2500;
        final percent = (current / goal).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2980), Color(0xFF26D0CE)], // Ocean Blue Gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF26D0CE).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                // Progress Circle
                SizedBox(
                  height: 50,
                  width: 50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                      ),
                      const Icon(Icons.water_drop, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hydration Goal",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$current / $goal ml",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.2, curve: Curves.easeOut),
        );
      },
    );
  }
}