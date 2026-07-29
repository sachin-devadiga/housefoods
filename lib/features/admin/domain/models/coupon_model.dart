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
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrderValue': minOrderValue,
      'expiryDate': expiryDate,
      'isActive': isActive,
    };
  }

  factory CouponModel.fromMap(Map<String, dynamic> map, String docId) {
    return CouponModel(
      id: docId,
      code: map['code'] ?? '',
      discountType: map['discountType'] ?? 'flat',
      discountValue: (map['discountValue'] ?? 0.0).toDouble(),
      minOrderValue: (map['minOrderValue'] ?? 0.0).toDouble(),
      expiryDate: map['expiryDate'] as DateTime,
      isActive: map['isActive'] ?? true,
    );
  }
}
