class RewardTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'credit' or 'debit'
  final String category; // 'referral', 'signup_bonus', 'order_payment'
  final String description;
  final DateTime timestamp;

  RewardTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'description': description,
      'timestamp': timestamp,
    };
  }

  factory RewardTransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return RewardTransactionModel(
      id: docId,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      type: map['type'] ?? 'credit',
      category: map['category'] ?? 'referral',
      description: map['description'] ?? '',
      timestamp: map['timestamp'] as DateTime,
    );
  }
}
