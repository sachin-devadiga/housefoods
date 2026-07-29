class ReviewModel {
  final String id;
  final String customerId;
  final String customerName;
  final String kitchenId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.kitchenId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'kitchen': kitchenId,
      'rating': rating,
      'comment': comment,
      'customer_id': customerId,
      'customer_name': customerName,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(String key) {
      final val = map[key];
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return ReviewModel(
      id: docId,
      customerId: (map['user'] ?? map['customerId'] ?? '').toString(),
      customerName: map['user_details']?['name'] as String? ?? map['customerName'] ?? 'Anonymous',
      kitchenId: (map['kitchen'] ?? map['kitchenId'] ?? '').toString(),
      rating: double.tryParse(map['rating']?.toString() ?? '0') ?? 0.0,
      comment: map['comment'] ?? '',
      createdAt: parseDate('created_at'),
    );
  }
}
