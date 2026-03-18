import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../models/leak_log_model.dart';
import '../../../services/iot_service.dart';
import '../../../utils/page_transition.dart';
import 'incident_detail_screen.dart'; // Ensure this file exists from the previous step

class PipelineHistoryScreen extends StatefulWidget {
  const PipelineHistoryScreen({super.key});

  @override
  State<PipelineHistoryScreen> createState() => _PipelineHistoryScreenState();
}

class _PipelineHistoryScreenState extends State<PipelineHistoryScreen> {
  final IoTService _ioTService = IoTService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Flow History & Reports', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- INFO CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Column(
                children: [
                  Text("SYSTEM VARIANCE", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  SizedBox(height: 8),
                  Text("0.0 L/min", style: TextStyle(color: Color(0xFF00F2FF), fontSize: 32, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Pipeline integrity actively monitored.", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

            const SizedBox(height: 32),

            // --- GRAPH LEGEND ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(color: const Color(0xFF00F2FF), label: "Flow In"),
                const SizedBox(width: 24),
                _buildLegendItem(color: Colors.white70, label: "Flow Out"),
              ],
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // --- THE LINE CHART (Fixed Height) ---
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${value.toInt()}:00', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 10));
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: 24, minY: 0, maxY: 60,
                  lineBarsData: [
                    // FLOW IN (Cyan)
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 45.5), FlSpot(4, 46.0), FlSpot(8, 55.2), FlSpot(12, 45.5), FlSpot(16, 42.1), FlSpot(20, 45.5), FlSpot(24, 45.5),
                      ],
                      isCurved: true,
                      color: const Color(0xFF00F2FF),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: const Color(0xFF00F2FF).withValues(alpha: 0.1)),
                    ),
                    // FLOW OUT (White/Grey - Overlapping)
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 45.5), FlSpot(4, 46.0), FlSpot(8, 55.2), FlSpot(12, 45.5), FlSpot(16, 42.1), FlSpot(20, 45.5), FlSpot(24, 45.5),
                      ],
                      isCurved: true,
                      color: Colors.white54,
                      barWidth: 2,
                      dashArray: [5, 5],
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
            ),

            const SizedBox(height: 40),

            // --- INCIDENT HISTORY HEADER ---
            const Row(
              children: [
                Icon(Icons.history_edu, color: Colors.white54, size: 20),
                SizedBox(width: 8),
                Text(
                  "INCIDENT HISTORY",
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 16),

            // --- HISTORICAL INCIDENTS LIST ---
            StreamBuilder<List<LeakLog>>(
              stream: _ioTService.streamSystemActiveLeaks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF00F2FF))),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: const Center(
                      child: Text("No incidents recorded.", style: TextStyle(color: Colors.white54)),
                    ),
                  ).animate().fadeIn(delay: 600.ms);
                }

                final logs = snapshot.data!;

                return ListView.builder(
                  shrinkWrap: true, // Prevents infinite height error inside ScrollView
                  physics: const NeverScrollableScrollPhysics(), // Disables inner scrolling
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildIncidentCard(context, log).animate().fadeIn(delay: Duration(milliseconds: 600 + (index * 100))).slideY(begin: 0.1);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- UPDATED: Card UI for each historical leak (Now Clickable) ---
  Widget _buildIncidentCard(BuildContext context, LeakLog log) {
    final bool isResolved = log.status == 'Resolved';
    final Color statusColor = isResolved ? Colors.greenAccent : const Color(0xFFFF4B2B);

    // Calculate dynamic duration
    final Duration? duration = log.resolvedAt?.difference(log.startTime);
    final String durationText = duration != null
        ? "${duration.inHours}h ${duration.inMinutes.remainder(60)}m to resolve"
        : "Ongoing investigation...";

    return GestureDetector(
      onTap: () {
        // Navigates to the detailed timeline view
        Navigator.push(context, SlideFadeRoute(page: IncidentDetailScreen(log: log)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isResolved ? Colors.white.withValues(alpha: 0.1) : statusColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(log.startTime),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Details: Location / Ward
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text("Ward: ${log.wardId}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14), // Added arrow indicator
              ],
            ),

            const SizedBox(height: 12),

            // Details: Resolution Time
            Row(
              children: [
                Icon(isResolved ? Icons.timer : Icons.timer_outlined,
                    color: isResolved ? Colors.orangeAccent : Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Resolution Time: $durationText",
                  style: TextStyle(
                      color: isResolved ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isResolved ? FontWeight.w600 : FontWeight.normal
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}