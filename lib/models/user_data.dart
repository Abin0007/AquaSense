import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String wardId;
  final String? phoneNumber;
  final bool isPhoneVerified;
  final Timestamp createdAt;
  final bool hasActiveConnection;
  final String? profileImageUrl;
  final Timestamp? lastReadAnnouncementsTimestamp;

  // --- HYDRATION MODULE FIELDS ---
  final int? hydrationGoal;
  final String? wakeUpTime;
  final String? bedTime; // NEW
  final String? gender;  // NEW
  final int? weight;     // NEW

  UserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.wardId,
    this.phoneNumber,
    this.isPhoneVerified = false,
    required this.createdAt,
    this.hasActiveConnection = false,
    this.profileImageUrl,
    this.lastReadAnnouncementsTimestamp,
    this.hydrationGoal,
    this.wakeUpTime,
    this.bedTime,
    this.gender,
    this.weight,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserData(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'citizen',
      wardId: data['wardId'] ?? '',
      phoneNumber: data['phoneNumber'],
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      hasActiveConnection: data['hasActiveConnection'] ?? false,
      profileImageUrl: data['profileImageUrl'],
      lastReadAnnouncementsTimestamp: data['lastReadAnnouncementsTimestamp'],
      hydrationGoal: data['hydrationGoal'],
      wakeUpTime: data['wakeUpTime'],
      bedTime: data['bedTime'],
      gender: data['gender'],
      weight: data['weight'],
    );
  }

  UserData copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? wardId,
    String? phoneNumber,
    bool? isPhoneVerified,
    Timestamp? createdAt,
    bool? hasActiveConnection,
    String? profileImageUrl,
    Timestamp? lastReadAnnouncementsTimestamp,
    int? hydrationGoal,
    String? wakeUpTime,
    String? bedTime,
    String? gender,
    int? weight,
  }) {
    return UserData(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      wardId: wardId ?? this.wardId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      createdAt: createdAt ?? this.createdAt,
      hasActiveConnection: hasActiveConnection ?? this.hasActiveConnection,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastReadAnnouncementsTimestamp: lastReadAnnouncementsTimestamp ?? this.lastReadAnnouncementsTimestamp,
      hydrationGoal: hydrationGoal ?? this.hydrationGoal,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      bedTime: bedTime ?? this.bedTime,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
    );
  }
}