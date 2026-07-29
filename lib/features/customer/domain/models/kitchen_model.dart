import 'package:intl/intl.dart';
import 'business_hours_model.dart';

class KitchenModel {
  final String id;
  final String chefId;
  final String name;
  final String chefName;
  final String address;
  final double rating;
  final int totalRatings;
  final String imageUrl;
  final List<String> galleryImages;
  final List<String> specialties;
  final List<String> categories;
  final bool isOpen;
  final bool isVeg;
  final String status;
  final double latitude;
  final double longitude;
  final String? fssaiNumber;
  final String? idProofUrl;
  final String? licenseUrl;
  final Map<String, BusinessHoursModel> businessHours;

  KitchenModel({
    required this.id,
    required this.chefId,
    required this.name,
    required this.chefName,
    required this.address,
    required this.rating,
    required this.totalRatings,
    required this.imageUrl,
    this.galleryImages = const [],
    required this.specialties,
    required this.categories,
    required this.isOpen,
    this.isVeg = true,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.fssaiNumber,
    this.idProofUrl,
    this.licenseUrl,
    this.businessHours = const {},
  });

  /// Computes if the kitchen is open right now based on schedule and manual override
  bool get isOperatingNow {
    if (!isOpen) return false; // Manual override takes precedence
    if (businessHours.isEmpty) return true; // Default if no hours set

    final now = DateTime.now();
    final String dayName = DateFormat('EEEE').format(now);
    final hours = businessHours[dayName];

    if (hours == null || hours.isClosed) return false;

    final int nowInMinutes = now.hour * 60 + now.minute;
    final int openInMinutes = hours.openTime.hour * 60 + hours.openTime.minute;
    final int closeInMinutes = hours.closeTime.hour * 60 + hours.closeTime.minute;

    return nowInMinutes >= openInMinutes && nowInMinutes <= closeInMinutes;
  }

  factory KitchenModel.fromMap(Map<String, dynamic> map, String docId) {
    Map<String, BusinessHoursModel> bh = {};
    if (map['businessHours'] != null) {
      (map['businessHours'] as Map<String, dynamic>).forEach((key, value) {
        bh[key] = BusinessHoursModel.fromMap(Map<String, dynamic>.from(value));
      });
    }

    return KitchenModel(
      id: docId,
      chefId: map['chefId'] ?? '',
      name: map['name'] ?? '',
      chefName: map['chefName'] ?? '',
      address: map['address'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      galleryImages: List<String>.from(map['galleryImages'] ?? []),
      specialties: List<String>.from(map['specialties'] ?? []),
      categories: List<String>.from(map['categories'] ?? []),
      isOpen: map['isOpen'] ?? true,
      isVeg: map['is_veg'] ?? map['isVeg'] ?? true,
      status: map['status'] ?? 'pending',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      fssaiNumber: map['fssaiNumber'],
      idProofUrl: map['idProofUrl'],
      licenseUrl: map['licenseUrl'],
      businessHours: bh,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> bhMap = {};
    businessHours.forEach((key, value) {
      bhMap[key] = value.toMap();
    });

    return {
      'chefId': chefId,
      'name': name,
      'chefName': chefName,
      'address': address,
      'rating': rating,
      'totalRatings': totalRatings,
      'imageUrl': imageUrl,
      'galleryImages': galleryImages,
      'specialties': specialties,
      'categories': categories,
      'isOpen': isOpen,
      'is_veg': isVeg,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'fssaiNumber': fssaiNumber,
      'idProofUrl': idProofUrl,
      'licenseUrl': licenseUrl,
      'businessHours': bhMap,
    };
  }
}
