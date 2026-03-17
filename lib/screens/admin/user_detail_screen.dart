import 'package:aquasense/models/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aquasense/utils/location_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _dashStart = Color(0xFF0F2027);
const Color _dashMid = Color(0xFF203A43);
const Color _dashEnd = Color(0xFF2C5364);
const Color _cyanCustom = Color(0xFF00F2FF);
const Color _dangerRed = Color(0xFFFF4B2B);

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  // --- State for Ward Selection Dialog ---
  final LocationService _locationService = LocationService();
  List<String> _dialogStates = [];
  List<String> _dialogDistricts = [];
  List<String> _dialogWards = [];
  String? _dialogSelectedState;
  String? _dialogSelectedDistrict;
  String? _dialogSelectedWard;
  bool _isDialogLoadingStates = false;
  bool _isDialogLoadingDistricts = false;
  bool _isDialogLoadingWards = false;

  @override
  void initState() {
    super.initState();
    _loadDialogStates();
  }

  // --- Location Data Loaders ---
  Future<void> _loadDialogStates() async {
    if (!mounted) return;
    setState(() => _isDialogLoadingStates = true);
    final loadedStates = await _locationService.getStates();
    if (mounted) {
      setState(() {
        _dialogStates = loadedStates;
        _isDialogLoadingStates = false;
      });
    }
  }

  Future<void> _loadDialogDistricts(String state, Function setDialogState) async {
    if (!mounted) return;
    setDialogState(() => _isDialogLoadingDistricts = true);
    final loadedDistricts = await _locationService.getDistricts(state);
    if (mounted) {
      setDialogState(() {
        _dialogDistricts = loadedDistricts;
        _isDialogLoadingDistricts = false;
      });
    }
  }

  Future<void> _loadDialogWards(String state, String district, Function setDialogState) async {
    if (!mounted) return;
    setDialogState(() => _isDialogLoadingWards = true);
    final loadedWards = await _locationService.getWards(state, district);
    if (mounted) {
      setDialogState(() {
        _dialogWards = loadedWards;
        _isDialogLoadingWards = false;
      });
    }
  }

  // --- Dropdown Styles ---
  DropDownDecoratorProps _getDropdownStyle(String hint, IconData icon) {
    return DropDownDecoratorProps(
      baseStyle: const TextStyle(color: Colors.white),
      dropdownSearchDecoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: _cyanCustom),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _cyanCustom)),
      ),
    );
  }

  // --- Role Update Dialog ---
  void _showUpdateRoleDialog(UserData currentUserData) {
    final List<String> availableRoles = ['citizen', 'supervisor'];
    String? roleToUpdate = availableRoles.contains(currentUserData.role) ? currentUserData.role : null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF152D4E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              title: const Text('Update User Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: availableRoles.map((String role) => Theme(
                  data: ThemeData(unselectedWidgetColor: Colors.white54),
                  child: RadioListTile<String>(
                    title: Text(role.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                    value: role,
                    groupValue: roleToUpdate,
                    onChanged: (String? value) {
                      setDialogState(() => roleToUpdate = value);
                    },
                    activeColor: _cyanCustom,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                )).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: (roleToUpdate != null && roleToUpdate != currentUserData.role)
                      ? () {
                    Navigator.of(dialogContext).pop();
                    _updateUserData({'role': roleToUpdate});
                  } : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _cyanCustom,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text('UPDATE ROLE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Ward Assignment Dialog ---
  void _showAssignWardDialog(UserData currentUserData) {
    _dialogSelectedState = null;
    _dialogSelectedDistrict = null;
    _dialogSelectedWard = null;
    _dialogDistricts = [];
    _dialogWards = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool canUpdate = _dialogSelectedWard != null && _dialogSelectedWard != currentUserData.wardId;

            return AlertDialog(
              backgroundColor: const Color(0xFF152D4E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              title: const Text('Assign Operations Ward', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownSearch<String>(
                      popupProps: PopupProps.menu(
                          showSearchBox: true,
                          menuProps: const MenuProps(backgroundColor: Color(0xFF152D4E)),
                          searchFieldProps: TextFieldProps(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Search State",
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              )
                          ),
                          itemBuilder: (context, item, isSelected) => ListTile(title: Text(item, style: const TextStyle(color: Colors.white)))
                      ),
                      items: _dialogStates,
                      enabled: !_isDialogLoadingStates,
                      dropdownDecoratorProps: _getDropdownStyle(_isDialogLoadingStates ? "Loading States..." : "Select State", Icons.map_outlined),
                      onChanged: (value) {
                        if (value != null && value != _dialogSelectedState) {
                          _loadDialogDistricts(value, setDialogState);
                          setDialogState(() {
                            _dialogSelectedState = value;
                            _dialogSelectedDistrict = null;
                            _dialogSelectedWard = null;
                            _dialogDistricts = [];
                            _dialogWards = [];
                          });
                        }
                      },
                      selectedItem: _dialogSelectedState,
                    ),
                    const SizedBox(height: 16),

                    if (_dialogSelectedState != null)
                      DropdownSearch<String>(
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: const MenuProps(backgroundColor: Color(0xFF152D4E)),
                            searchFieldProps: TextFieldProps(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Search District",
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.2),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                )
                            ),
                            itemBuilder: (context, item, isSelected) => ListTile(title: Text(item, style: const TextStyle(color: Colors.white)))
                        ),
                        items: _dialogDistricts,
                        enabled: !_isDialogLoadingDistricts && _dialogDistricts.isNotEmpty,
                        dropdownDecoratorProps: _getDropdownStyle(_isDialogLoadingDistricts ? "Loading Districts..." : (_dialogDistricts.isEmpty ? "No Districts Found" : "Select District"), Icons.location_city),
                        onChanged: (value) {
                          if (value != null && value != _dialogSelectedDistrict) {
                            _loadDialogWards(_dialogSelectedState!, value, setDialogState);
                            setDialogState(() {
                              _dialogSelectedDistrict = value;
                              _dialogSelectedWard = null;
                              _dialogWards = [];
                            });
                          }
                        },
                        selectedItem: _dialogSelectedDistrict,
                      ),
                    const SizedBox(height: 16),

                    if (_dialogSelectedDistrict != null)
                      DropdownSearch<String>(
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            menuProps: const MenuProps(backgroundColor: Color(0xFF152D4E)),
                            searchFieldProps: TextFieldProps(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Search Ward",
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.2),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                )
                            ),
                            itemBuilder: (context, item, isSelected) => ListTile(title: Text(item, style: const TextStyle(color: Colors.white)))
                        ),
                        items: _dialogWards,
                        enabled: !_isDialogLoadingWards && _dialogWards.isNotEmpty,
                        dropdownDecoratorProps: _getDropdownStyle(_isDialogLoadingWards ? "Loading Wards..." : (_dialogWards.isEmpty ? "No Wards Found" : "Select Ward"), Icons.maps_home_work_outlined),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => _dialogSelectedWard = value);
                          }
                        },
                        selectedItem: _dialogSelectedWard,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: canUpdate
                      ? () {
                    Navigator.of(dialogContext).pop();
                    _updateUserData({'wardId': _dialogSelectedWard});
                  } : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _cyanCustom,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text('ASSIGN WARD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Deletion Request Logic ---
  Future<void> _requestUserDeletion(UserData userData) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    bool? confirmRequest = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF152D4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _dangerRed.withOpacity(0.5))),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: _dangerRed),
            SizedBox(width: 8),
            Text('Flag for Deletion?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
            'This will flag ${userData.name} for permanent system deletion. This action requires confirmation and restricts user access. Are you sure?',
            style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('FLAG USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmRequest == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userData.uid)
            .update({'deletionRequested': true, 'deletionRequestedAt': FieldValue.serverTimestamp()});
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('${userData.name} flagged for deletion.'), backgroundColor: Colors.orangeAccent));
          navigator.pop();
        }
      } catch (e) {
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _dangerRed));
      }
    }
  }

  Future<void> _updateUserData(Map<String, dynamic> dataToUpdate) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(dataToUpdate);
      if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('User data updated successfully!'), backgroundColor: Colors.greenAccent));
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: _dangerRed));
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return _dangerRed;
      case 'supervisor': return Colors.purpleAccent;
      default: return _cyanCustom;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dashStart, _dashMid, _dashEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- APP BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('User Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5)),

                    // Delete/Flag Button Stream
                    StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData = UserData.fromFirestore(snapshot.data!);
                            final dataMap = snapshot.data!.data() as Map<String, dynamic>?;
                            final bool alreadyFlagged = dataMap?.containsKey('deletionRequested') ?? false && dataMap!['deletionRequested'] == true;

                            if (userData.role == 'admin') return const SizedBox(width: 48);

                            return IconButton(
                              icon: Icon(alreadyFlagged ? Icons.restore_from_trash : Icons.person_remove, color: alreadyFlagged ? Colors.grey : _dangerRed),
                              tooltip: alreadyFlagged ? 'Undo Deletion Request' : 'Flag User for Deletion',
                              onPressed: () => alreadyFlagged
                                  ? _updateUserData({'deletionRequested': false, 'deletionRequestedAt': FieldValue.delete()})
                                  : _requestUserDeletion(userData),
                            );
                          }
                          return const SizedBox(width: 48);
                        }
                    ),
                  ],
                ),
              ),

              // --- MAIN CONTENT ---
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _cyanCustom));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: _dangerRed)));
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(child: Text('User not found.', style: TextStyle(color: Colors.white54)));
                    }

                    final userData = UserData.fromFirestore(snapshot.data!);
                    final dataMap = snapshot.data!.data() as Map<String, dynamic>?;
                    final bool isFlaggedForDeletion = dataMap?.containsKey('deletionRequested') ?? false && dataMap!['deletionRequested'] == true;
                    final roleColor = _getRoleColor(userData.role);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          // 1. Profile Header
                          _buildProfileHeader(userData, roleColor),
                          const SizedBox(height: 32),

                          // 2. Deletion Warning
                          if(isFlaggedForDeletion)
                            Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                    color: _dangerRed.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _dangerRed.withOpacity(0.5))
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.warning_amber_rounded, color: _dangerRed, size: 28),
                                    SizedBox(width: 16),
                                    Expanded(child: Text('This user account is currently flagged for permanent deletion.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4))),
                                  ],
                                )
                            ).animate().fadeIn().slideY(begin: -0.1).shake(hz: 3, duration: 400.ms),

                          // 3. User Details Container
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(Icons.email_outlined, "Email Address", userData.email),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10, height: 1)),
                                _buildDetailRow(Icons.phone_outlined, "Phone Number", userData.phoneNumber ?? 'Not Provided',
                                  trailing: Icon(userData.isPhoneVerified ? Icons.verified : Icons.error_outline, color: userData.isPhoneVerified ? Colors.greenAccent : Colors.orangeAccent, size: 18),
                                ),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10, height: 1)),
                                _buildDetailRow(Icons.location_city_outlined, "Assigned Ward", userData.wardId.isEmpty ? 'Unassigned' : userData.wardId),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10, height: 1)),
                                _buildDetailRow(Icons.calendar_today_outlined, "Member Since", DateFormat('MMM dd, yyyy').format(userData.createdAt.toDate())),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10, height: 1)),
                                _buildDetailRow(Icons.water_drop_outlined, "Connection Status", userData.hasActiveConnection ? 'Active' : 'Inactive',
                                    valueColor: userData.hasActiveConnection ? Colors.greenAccent : Colors.white54
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                          const SizedBox(height: 32),

                          // 4. Admin Actions
                          if (userData.role != 'admin') ...[
                            Row(
                              children: [
                                const Text("ADMINISTRATIVE ACTIONS", style: TextStyle(color: _cyanCustom, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                const SizedBox(width: 12),
                                Expanded(child: Container(height: 1, color: _cyanCustom.withOpacity(0.3))),
                              ],
                            ).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 16),

                            _buildAdminActionTile(
                              title: 'Modify System Role',
                              currentValue: 'Current: ${userData.role.toUpperCase()}',
                              icon: Icons.admin_panel_settings_outlined,
                              onTap: () => _showUpdateRoleDialog(userData),
                            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

                            const SizedBox(height: 12),

                            _buildAdminActionTile(
                              title: 'Assign Operations Ward',
                              currentValue: userData.wardId.isEmpty ? 'Tap to configure ward mapping' : 'Assigned to: ${userData.wardId}',
                              icon: Icons.map_outlined,
                              onTap: () => _showAssignWardDialog(userData),
                            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE UI COMPONENTS ---

  Widget _buildProfileHeader(UserData userData, Color roleColor) {
    ImageProvider backgroundImage;
    if (userData.profileImageUrl != null && userData.profileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(userData.profileImageUrl!);
    } else {
      backgroundImage = const AssetImage('assets/icon/app_icon.png');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [roleColor, roleColor.withOpacity(0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: roleColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF152D4E),
            backgroundImage: backgroundImage,
            onBackgroundImageError: (_, __) {},
            child: backgroundImage is AssetImage || userData.profileImageUrl == null || userData.profileImageUrl!.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.white54)
                : null,
          ),
        ),
        const SizedBox(height: 20),
        Text(userData.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: roleColor.withOpacity(0.5))),
          child: Text(userData.role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ],
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _cyanCustom, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminActionTile({required String title, required String currentValue, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(currentValue, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }
}