import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/screens/connections/apply_connection_screen.dart';
import 'package:aquasense/screens/connections/document_viewer_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConnectionStatusDetailScreen extends StatelessWidget {
  final ConnectionRequest request;

  const ConnectionStatusDetailScreen({super.key, required this.request});

  Future<void> _reapplyForConnection(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('connection_requests')
          .doc(request.id)
          .delete();

      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const ApplyConnectionScreen()),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Could not process re-application. $e')),
        );
      }
    }
  }

  Future<void> _deleteRequest(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    bool? confirmDelete = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        title: const Text('Delete Request?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to permanently delete this connection request?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('connection_requests')
            .doc(request.id)
            .delete();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Connection request deleted.')),
        );
        navigator.pop();
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chronologicalHistory = List<StatusUpdate>.from(request.statusHistory)
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    final uniqueHistoryMap = <String, StatusUpdate>{};
    for (var item in chronologicalHistory) {
      uniqueHistoryMap[item.status] = item;
    }

    final uniqueHistory = uniqueHistoryMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Status'),
        backgroundColor: const Color(0xFF152D4E),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRequest(context),
            tooltip: 'Delete Request',
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 24),
            if (request.rejectionReason != null &&
                request.rejectionReason!.isNotEmpty) ...[
              _buildRejectionCard(),
              const SizedBox(height: 30),
              if (request.currentStatus == 'Rejected')
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Submit New Application'),
                  onPressed: () => _reapplyForConnection(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Status Timeline',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (uniqueHistory.isEmpty)
              const Center(
                  child: Text('No status history yet.',
                      style: TextStyle(color: Colors.white70)))
            else
              ...uniqueHistory.asMap().entries.map((entry) {
                final index = entry.key;
                final statusUpdate = entry.value;
                final isFirst = index == 0;
                final isLast = index == uniqueHistory.length - 1;
                return _buildTimelineTile(statusUpdate,
                    isFirst: isFirst, isLast: isLast);
              }),

            if (request.currentStatus == 'Completed' && request.finalConnectionImageUrl != null)
              _buildCompletedSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Installation Image',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(request.finalConnectionImageUrl!),
        ),
      ],
    );
  }


  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Request ID: ${request.id}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          request.currentStatus,
          style: TextStyle(
              color: request.currentStatus == 'Rejected'
                  ? Colors.redAccent
                  : Colors.cyanAccent,
              fontSize: 28,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Applicant:', request.userName),
          _buildInfoRow('Address:', request.address),
          const Divider(color: Colors.white24, height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('View Residential Proof'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) =>
                        DocumentViewerScreen(url: request.residentialProofUrl)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRejectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.red.withAlpha(30),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.redAccent.withAlpha(100))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Reason for Rejection',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.rejectionReason!,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTile(StatusUpdate statusUpdate,
      {bool isFirst = false, bool isLast = false}) {
    IconData icon;
    Color iconColor;

    switch (statusUpdate.status) {
      case 'Application Submitted':
        icon = Icons.file_present_rounded;
        iconColor = Colors.blueAccent;
        break;
      case 'Document Verification':
        icon = Icons.document_scanner_outlined;
        iconColor = Colors.orangeAccent;
        break;
      case 'Site Visit Scheduled':
        icon = Icons.location_on_outlined;
        iconColor = Colors.purpleAccent;
        break;
      case 'Approved':
        icon = Icons.check_circle_outline;
        iconColor = Colors.greenAccent;
        break;
      case 'Completed':
        icon = Icons.done_all_rounded;
        iconColor = Colors.cyanAccent;
        break;
      case 'Rejected':
        icon = Icons.cancel_outlined;
        iconColor = Colors.redAccent;
        break;
      default:
        icon = Icons.hourglass_empty_rounded;
        iconColor = Colors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : Colors.white24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withAlpha(50),
                    border: Border.all(color: iconColor, width: 2),
                    boxShadow: isFirst
                        ? [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                        : [],
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
              isFirst ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!isFirst) const SizedBox(height: 16),
                Text(
                  statusUpdate.status,
                  style: TextStyle(
                    color: isFirst ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy, h:mm a')
                      .format(statusUpdate.updatedAt.toDate()),
                  style: TextStyle(
                    color: isFirst ? Colors.white70 : Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusUpdate.description,
                  style: TextStyle(
                    color: isFirst ? Colors.white70 : Colors.white54,
                    fontSize: 14,
                  ),
                ),
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}