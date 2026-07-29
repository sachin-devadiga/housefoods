double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

class DeliveryLogModel {
  final String id;
  final String orderId;
  final DateTime date;
  final String status; // 'pending', 'delivered', 'skipped', 'missed'
  final double refundAmount;
  final double? rating; // New: Daily rating (1-5)
  final String? feedback; // New: Text feedback

  DeliveryLogModel({
    required this.id,
    required this.orderId,
    required this.date,
    required this.status,
    this.refundAmount = 0.0,
    this.rating,
    this.feedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'order': orderId,
      'date': DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0],
      'status': status,
      'refund_amount': refundAmount,
      'rating': rating,
      'feedback': feedback,
    };
  }

  factory DeliveryLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(String key) {
      final val = map[key];
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return DeliveryLogModel(
      id: docId,
      orderId: (map['order'] ?? map['orderId'] ?? '').toString(),
      date: parseDate('date'),
      status: map['status'] ?? 'pending',
      refundAmount: _parseDouble(map['refund_amount']) ?? _parseDouble(map['refundAmount']) ?? 0.0,
      rating: _parseDouble(map['rating']),
      feedback: map['feedback']?.toString(),
    );
  }
}
