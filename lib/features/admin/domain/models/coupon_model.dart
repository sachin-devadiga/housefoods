class CouponModel {
  final String id;
  final String code;
  final String discountType; // 'flat' or 'percentage'
  final double discountValue;
  final double minOrderValue;
  final DateTime expiryDate;
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.expiryDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code.toUpperCase(),
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'expiry_date': expiryDate.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory CouponModel.fromMap(Map<String, dynamic> map, String docId) {
    return CouponModel(
      id: docId,
      code: map['code'] ?? '',
      discountType: map['discount_type'] ?? map['discountType'] ?? 'flat',
      discountValue: (map['discount_value'] ?? map['discountValue'] ?? 0.0).toDouble(),
      minOrderValue: (map['min_order_value'] ?? map['minOrderValue'] ?? 0.0).toDouble(),
      expiryDate: DateTime.tryParse(map['expiry_date']?.toString() ?? map['expiryDate']?.toString() ?? '') ?? DateTime.now(),
      isActive: map['is_active'] ?? map['isActive'] ?? true,
    );
  }
}
