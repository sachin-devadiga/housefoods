class BannerModel {
  final String id;
  final String imageUrl;
  final String actionType; // 'kitchen', 'coupon', 'external'
  final String? actionId;
  final bool isActive;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.actionType,
    this.actionId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'actionType': actionType,
      'actionId': actionId,
      'isActive': isActive,
    };
  }

  factory BannerModel.fromMap(Map<String, dynamic> map, String docId) {
    return BannerModel(
      id: docId,
      imageUrl: map['imageUrl'] ?? '',
      actionType: map['actionType'] ?? 'none',
      actionId: map['actionId'],
      isActive: map['isActive'] ?? true,
    );
  }
}
