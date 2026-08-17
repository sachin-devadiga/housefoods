class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String kitchenId;
  final String kitchenName;
  final String chefId;
  final String chefName;
  final String planId;
  final String planName;
  final double amount;
  final String deliveryAddress;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'active', 'completed', 'cancelled'
  final String paymentId;
  final DateTime createdAt;
  final bool isPaused;
  final String deliverySlotId; // New field
  final String mealType; // New field: 'lunch' or 'dinner'

  OrderModel({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.kitchenId,
    required this.kitchenName,
    this.chefId = '',
    this.chefName = '',
    required this.planId,
    required this.planName,
    required this.amount,
    required this.deliveryAddress,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentId,
    required this.createdAt,
    this.isPaused = false,
    required this.deliverySlotId,
    required this.mealType,
  });

  Map<String, dynamic> toMap() {
    return {
      'kitchen': kitchenId,
      'plan': planId,
      'plan_name': planName,
      'amount': amount.toString(),
      'delivery_address': deliveryAddress,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'status': status,
      'payment_id': paymentId,
      'delivery_slot_id': deliverySlotId,
      'meal_type': mealType,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(String key) {
      final val = map[key];
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    final kitchenDetails = map['kitchen_details'] as Map<String, dynamic>?;
    final customerDetails = map['customer_details'] as Map<String, dynamic>?;

    return OrderModel(
      id: docId,
      customerId: (map['customer'] ?? map['customerId'] ?? '').toString(),
      customerName: customerDetails?['name'] as String? ?? map['customerName'] ?? '',
      kitchenId: (map['kitchen'] ?? map['kitchenId'] ?? '').toString(),
      kitchenName: kitchenDetails?['name'] as String? ?? map['kitchenName'] ?? '',
      chefId: (kitchenDetails?['chef'] ?? '').toString(),
      chefName: (kitchenDetails?['chef_details']?['name'] as String?) ?? '',
      planId: (map['plan'] ?? map['planId'] ?? '').toString(),
      planName: map['plan_name'] ?? map['planName'] ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      deliveryAddress: map['delivery_address'] ?? map['deliveryAddress'] ?? '',
      startDate: parseDate('start_date'),
      endDate: parseDate('end_date'),
      status: map['status'] ?? 'pending',
      paymentId: map['payment_id'] ?? map['paymentId'] ?? '',
      createdAt: parseDate('created_at'),
      isPaused: map['is_paused'] ?? map['isPaused'] ?? false,
      deliverySlotId: map['delivery_slot_id'] ?? map['deliverySlotId'] ?? '',
      mealType: map['meal_type'] ?? map['mealType'] ?? 'lunch',
    );
  }
}
