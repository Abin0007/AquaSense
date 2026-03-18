import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/screens/complaints/components/complaint_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComplaintListTile extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback? onDelete;
  final int? rating; // Accepts rating (can be null)

  const ComplaintListTile({
    super.key,
    required this.complaint,
    this.onDelete,
    this.rating, // Make rating optional
  });

  @override
  Widget build(BuildContext context) {
    bool isResolved = complaint.status.toLowerCase() == 'resolved';
    int? displayRating = rating ?? complaint.citizenRating; // Use passed rating or from complaint data

    return Container(
      // *** MODIFIED: Use margin instead of Padding if rating might be below ***
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        // *** MODIFIED: Keep all corners rounded ***
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        children: [
          _buildIconForType(complaint.type),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported on ${DateFormat('d MMM, yyyy').format(complaint.createdAt.toDate())}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                // --- Display Rating if available AND resolved ---
                if (displayRating != null && isResolved) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (index) => Icon(
                      index < displayRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    )),
                  ),
                ]
                // --- End Rating Display ---
              ],
            ),
          ),
          const SizedBox(width: 16),
          ComplaintStatusIndicator(status: complaint.status),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
              tooltip: 'Delete Complaint',
              // Visual feedback on press
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(), // Remove default padding
            )
          ]
        ],
      ),
    );
  }

  Widget _buildIconForType(String type) {
    // ... (keep existing _buildIconForType logic) ...
    IconData iconData;
    switch (type.toLowerCase()) {
      case 'leakage':
        iconData = Icons.water_drop_outlined;
        break;
      case 'quality':
        iconData = Icons.science_outlined;
        break;
      case 'no water':
        iconData = Icons.do_not_disturb_on_outlined;
        break;
      case 'billing':
        iconData = Icons.receipt_long_outlined;
        break;
      default:
        iconData = Icons.help_outline;
    }
    return Icon(iconData, color: Colors.cyanAccent, size: 28);
  }
}