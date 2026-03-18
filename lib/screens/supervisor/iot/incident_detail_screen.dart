import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/leak_log_model.dart';

class IncidentDetailScreen extends StatelessWidget {
  final LeakLog log;

  const IncidentDetailScreen({super.key, required this.log});

  // --- CORRECTED: Reliable Google Maps URL ---
  void _launchMap(double lat, double lng) async {
    // Official universal Google Maps search URL
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Incident Report', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text("INCIDENT ID: ${log.logId.toUpperCase().substring(0, 8)}", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text("Ward ID: ${log.wardId}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // Photo Evidence Grid
            if (log.arrivedPhotoUrl != null || log.resolvedPhotoUrl != null) ...[
              const Text("EVIDENCE LOG", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (log.arrivedPhotoUrl != null)
                    Expanded(child: _buildPhotoCard("Arrived on Site", log.arrivedPhotoUrl!)),
                  const SizedBox(width: 12),
                  if (log.resolvedPhotoUrl != null)
                    Expanded(child: _buildPhotoCard("Issue Resolved", log.resolvedPhotoUrl!)),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // Full Timeline
            const Text("RESOLUTION TIMELINE", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildTimelineNode(title: "Leak Detected", time: log.startTime, isFirst: true, isDone: true, icon: Icons.warning_amber_rounded, color: Colors.redAccent),
                  _buildTimelineNode(title: "Valves Shutdown", time: log.valvesShutdownAt, isDone: log.valvesShutdownAt != null, icon: Icons.settings, color: Colors.orangeAccent),
                  _buildTimelineNode(
                      title: "Arrived at Site",
                      time: log.arrivedAt,
                      isDone: log.arrivedAt != null,
                      icon: Icons.location_on,
                      color: Colors.cyanAccent,
                      onTapLoc: log.arrivedLocation != null ? () => _launchMap(log.arrivedLocation!.latitude, log.arrivedLocation!.longitude) : null
                  ),
                  _buildTimelineNode(
                      title: "Leak Resolved",
                      time: log.resolvedAt,
                      isLast: true,
                      isDone: log.resolvedAt != null,
                      icon: Icons.verified,
                      color: Colors.greenAccent,
                      onTapLoc: log.resolvedLocation != null ? () => _launchMap(log.resolvedLocation!.latitude, log.resolvedLocation!.longitude) : null
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(url, fit: BoxFit.cover, loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildTimelineNode({required String title, DateTime? time, bool isFirst = false, bool isLast = false, required bool isDone, required IconData icon, required Color color, VoidCallback? onTapLoc}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDone ? color.withValues(alpha: 0.2) : Colors.white10, shape: BoxShape.circle), child: Icon(icon, size: 16, color: isDone ? color : Colors.white30)),
              if (!isLast) Expanded(child: Container(width: 2, color: isDone ? color.withValues(alpha: 0.5) : Colors.white10, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isDone ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (time != null) Text(DateFormat('MMM dd, hh:mm a').format(time), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  if (onTapLoc != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onTapLoc,
                      child: const Row(children: [Icon(Icons.map, color: Colors.cyanAccent, size: 14), SizedBox(width: 4), Text("View GPS Coordinates", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.cyanAccent))]),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}