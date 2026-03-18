import 'dart:io';
import 'package:aquasense/models/connection_request_model.dart';
import 'package:aquasense/screens/connections/document_viewer_screen.dart';
import 'package:aquasense/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectionRequestDetailScreen extends StatefulWidget {
  final ConnectionRequest request;
  const ConnectionRequestDetailScreen({super.key, required this.request});

  @override
  State<ConnectionRequestDetailScreen> createState() => _ConnectionRequestDetailScreenState();
}

class _ConnectionRequestDetailScreenState extends State<ConnectionRequestDetailScreen> {
  bool _isCompleting = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('connection_requests').doc(widget.request.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xFF0F2027), body: Center(child: CircularProgressIndicator()));
        }
        final liveRequest = ConnectionRequest.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: const Color(0xFF0F2027),
          appBar: AppBar(
            title: const Text('Application Details'),
            backgroundColor: const Color(0xFF152D4E),
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildDetailRow('Applicant Name:', liveRequest.userName),
                  _buildDetailRow('Address:', liveRequest.address),
                  _buildDetailRow('Applied On:', DateFormat('d MMMM, yyyy').format(liveRequest.appliedAt.toDate())),
                  _buildDetailRow('Current Status:', liveRequest.currentStatus, isStatus: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.description_outlined),
                          label: const Text("View Proof"),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => DocumentViewerScreen(url: liveRequest.residentialProofUrl)),
                          ),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text("View on Map"),
                          onPressed: () => _launchMap(liveRequest, context),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40, color: Colors.white24),
                  _buildStatusUpdateSection(context, liveRequest),
                ],
              ),
              if (_isCompleting)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Finalizing Connection...", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMap(ConnectionRequest req, BuildContext context) async {
    final lat = req.latitude;
    final long = req.longitude;
    if (lat == null || long == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not provided for this request.')));
      return;
    }
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$long");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map.')));
      }
    }
  }

  Future<void> _updateStatus(BuildContext context, ConnectionRequest liveRequest, String newStatus, {String? description, String? rejectionReason}) async {
    if (liveRequest.currentStatus == newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status is already "$newStatus"')));
      return;
    }
    if (!context.mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final newStatusUpdate = StatusUpdate(
        status: newStatus,
        description: description ?? _getStatusDescription(newStatus),
        updatedAt: Timestamp.now(),
      );
      final updateData = {
        'currentStatus': newStatus,
        'statusHistory': FieldValue.arrayUnion([newStatusUpdate.toMap()]),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };
      await FirebaseFirestore.instance.collection('connection_requests').doc(liveRequest.id).update(updateData);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      if (newStatus == 'Rejected') navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  void _showRejectionDialog(BuildContext context, ConnectionRequest liveRequest) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C5364),
          title: const Text('Reject Application', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: 'Provide a reason for rejection'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Confirm Rejection'),
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  _updateStatus(context, liveRequest, 'Rejected', rejectionReason: reasonController.text.trim());
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog(BuildContext context, ConnectionRequest liveRequest) {
    XFile? imageFile;
    Position? location;
    final ImagePicker picker = ImagePicker();
    bool isFetchingLocation = false;
    showDialog(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C5364),
          title: const Text('Complete Connection', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Upload photo and add location of the completed installation.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                    if (pickedFile != null) setDialogState(() => imageFile = pickedFile);
                  },
                  child: Container(
                    height: 150, width: double.infinity,
                    decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(12)),
                    child: imageFile == null
                        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.camera_alt_outlined, color: Colors.white70), SizedBox(height: 8), Text('Take Photo', style: TextStyle(color: Colors.white70))]))
                        : Image.file(File(imageFile!.path), fit: BoxFit.cover),
                  ),
                ),
                const Divider(color: Colors.white24, height: 20),
                if (isFetchingLocation) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
                if (!isFetchingLocation && location != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Location captured!', style: TextStyle(color: Colors.greenAccent)),
                  ),
                if (!isFetchingLocation && location == null)
                  TextButton.icon(
                    icon: const Icon(Icons.my_location),
                    label: const Text('Get Current Location'),
                    onPressed: () async {
                      setDialogState(() => isFetchingLocation = true);
                      try {
                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
                        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception("Location permission not granted.");
                        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                        setDialogState(() => location = pos);
                      } catch (e) {
                        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      } finally {
                        setDialogState(() => isFetchingLocation = false);
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              onPressed: (imageFile == null || location == null) ? null : () {
                Navigator.of(dialogContext).pop();
                _completeConnection(context, liveRequest, imageFile!, location!);
              },
              child: const Text('Confirm & Complete'),
            ),
          ],
        );
      });
    });
  }

  void _showSuccessDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Connection Completed!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop();
              navigator.pop();
            },
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeConnection(BuildContext context, ConnectionRequest liveRequest, XFile imageFile, Position location) async {
    if (!mounted) return;
    setState(() => _isCompleting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final storageService = StorageService();
      final imageUrl = await storageService.uploadConnectionImage(imageFile, liveRequest.userId);
      final newStatusUpdate = StatusUpdate(
        status: 'Completed',
        description: _getStatusDescription('Completed'),
        updatedAt: Timestamp.now(),
      );
      final db = FirebaseFirestore.instance;
      final writeBatch = db.batch();
      final requestRef = db.collection('connection_requests').doc(liveRequest.id);
      writeBatch.update(requestRef, {
        'currentStatus': 'Completed',
        'statusHistory': FieldValue.arrayUnion([newStatusUpdate.toMap()]),
        'finalConnectionImageUrl': imageUrl,
        'finalConnectionLocation': GeoPoint(location.latitude, location.longitude),
        'connectionCreatedAt': FieldValue.serverTimestamp(),
      });
      final userRef = db.collection('users').doc(liveRequest.userId);
      writeBatch.update(userRef, {'hasActiveConnection': true});
      await writeBatch.commit();

      _showSuccessDialog();

    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to complete connection: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  Widget _buildStatusUpdateSection(BuildContext context, ConnectionRequest liveRequest) {
    if(liveRequest.currentStatus == 'Completed' || liveRequest.currentStatus == 'Rejected') {
      return Center(child: Text('This application has been ${liveRequest.currentStatus.toLowerCase()}.', style: const TextStyle(color: Colors.white70, fontSize: 16)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Update Application Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildStatusButton(context, liveRequest, 'Document Verification'),
        _buildStatusButton(context, liveRequest, 'Site Visit Scheduled'),
        _buildStatusButton(context, liveRequest, 'Approved'),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: ElevatedButton.icon(onPressed: () => _showRejectionDialog(context, liveRequest), icon: const Icon(Icons.close), label: const Text('Reject'), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)))),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: liveRequest.currentStatus == 'Approved' ? () => _showCompletionDialog(context, liveRequest) : null,
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton(BuildContext context, ConnectionRequest liveRequest, String status) {
    const statusOrder = ['Application Submitted', 'Document Verification', 'Site Visit Scheduled', 'Approved'];
    final currentIndex = statusOrder.indexOf(liveRequest.currentStatus);
    final targetIndex = statusOrder.indexOf(status);
    final bool isEnabled = (targetIndex == currentIndex + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton(
        onPressed: isEnabled ? () => _updateStatus(context, liveRequest, status) : null,
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: isEnabled ? Colors.white30 : Colors.grey.withValues(alpha: 0.2)),
            disabledForegroundColor: Colors.grey.withValues(alpha: 0.5)
        ),
        child: Text('Set to: $status'),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title ', style: const TextStyle(color: Colors.white70, fontSize: 15)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isStatus ? Colors.cyanAccent : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'Document Verification':
        return 'The provided documents are being verified by our team.';
      case 'Site Visit Scheduled':
        return 'A supervisor has been assigned to conduct a site visit.';
      case 'Approved':
        return 'Your application has been approved! The new connection will be installed shortly.';
      case 'Completed':
        return 'The new water connection has been successfully installed.';
      case 'Rejected':
        return 'The application has been rejected. Please review the reason provided.';
      default:
        return 'The application status has been updated.';
    }
  }
}