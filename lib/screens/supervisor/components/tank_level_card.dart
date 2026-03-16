import 'package:aquasense/models/water_tank_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TankLevelCard extends StatelessWidget {
  final WaterTank tank;
  final VoidCallback onUpdate; // Callback for update action preserved

  const TankLevelCard({super.key, required this.tank, required this.onUpdate});

  Color _getColorForLevel(int level) {
    if (level < 20) return Colors.redAccent;
    if (level < 50) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForLevel(tank.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // Clean up the name in case it uses the document ID with %20
                tank.tankName.replaceAll('%20', ' '),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // PRESERVED: MANUAL UPDATE BUTTON
              OutlinedButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Added seconds to the timestamp to clearly show the 2-second live updates
            'Last updated: ${DateFormat('d MMM, h:mm:ss a').format(tank.lastUpdated.toDate())}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // SMOOTHLY ANIMATED PROGRESS BAR FOR LIVE ESP32 UPDATES
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: tank.level / 100.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 12,
                        backgroundColor: Colors.grey.withAlpha(50),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 55, // Fixed width prevents the layout from jittering as numbers change
                child: TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: tank.level),
                  duration: const Duration(milliseconds: 1500),
                  builder: (context, value, child) {
                    return Text(
                      '$value%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}