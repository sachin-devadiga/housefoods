import 'address_model.dart';

class UserModel {
  final String uid;
  final String email;
  final String phoneNumber;
  final String name;
  final String role; // 'customer', 'chef', 'delivery_partner', or 'admin'
  final String? profileImage;
  final DateTime createdAt;
  final List<AddressModel> addresses;
  final List<String> favoriteKitchenIds;
  final String referralCode;
  final String? referredBy;
  final double walletBalance;
  final String dietaryPreference;
  final List<String> allergies;
  final String? fcmToken; // New: For targeted push notifications

  UserModel({
    required this.uid,
    this.email = '',
    this.phoneNumber = '',
    required this.name,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.addresses = const [],
    this.favoriteKitchenIds = const [],
    required this.referralCode,
    this.referredBy,
    this.walletBalance = 0.0,
    this.dietaryPreference = 'none',
    this.allergies = const [],
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'name': name,
      'role': role,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'addresses': addresses.map((e) => e.toMap()).toList(),
      'favoriteKitchenIds': favoriteKitchenIds,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'walletBalance': walletBalance,
      'dietaryPreference': dietaryPreference,
      'allergies': allergies,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'customer',
      profileImage: map['profileImage'] ?? map['avatar_url'],
      createdAt: DateTime.tryParse(
              map['createdAt']?.toString() ?? map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      addresses: (map['addresses'] as List? ?? [])
          .map((e) => AddressModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      favoriteKitchenIds: List<String>.from(map['favoriteKitchenIds'] ?? map['favorite_kitchen_ids'] ?? []),
      referralCode: map['referralCode'] ?? map['referral_code'] ?? '',
      referredBy: map['referredBy'] ?? map['referred_by'],
      walletBalance: (map['walletBalance'] ?? map['wallet_balance'] ?? 0.0).toDouble(),
      dietaryPreference: map['dietaryPreference'] ?? map['dietary_preference'] ?? 'none',
      allergies: List<String>.from(map['allergies'] ?? []),
      fcmToken: map['fcmToken'] ?? map['fcm_token'],
    );
  }
}
