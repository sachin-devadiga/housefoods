class SupportTicketModel {
  final String id;
  final String userId;
  final String userName;
  final String? orderId;
  final String category; // 'Quality', 'Delivery', 'Payment', 'Other'
  final String description;
  final String status; // 'open', 'in_progress', 'resolved'
  final DateTime createdAt;
  final List<Map<String, dynamic>> updates; // Admin notes or conversation

  SupportTicketModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.orderId,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.updates = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'orderId': orderId,
      'category': category,
      'description': description,
      'status': status,
      'createdAt': createdAt,
      'updates': updates,
    };
  }

  factory SupportTicketModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupportTicketModel(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      orderId: map['orderId'],
      category: map['category'] ?? 'Other',
      description: map['description'] ?? '',
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] as DateTime,
      updates: List<Map<String, dynamic>>.from(map['updates'] ?? []),
    );
  }
}
