import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String kitchenId;
  final String kitchenName;
  final String chefId;
  final String chefName;
  final String orderType; // 'one_time' or 'subscription'
  final String planId;
  final String planName;
  final double amount;
  final double subtotal;
  final double tax;
  final double platformFee;
  final double tip;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final DateTime? deliveryTime;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'active', 'completed', 'cancelled'
  final String paymentId;
  final DateTime createdAt;
  final bool isPaused;
  final String deliverySlotId;
  final String mealType;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.kitchenId,
    required this.kitchenName,
    this.chefId = '',
    this.chefName = '',
    this.orderType = 'subscription',
    this.planId = '',
    this.planName = '',
    required this.amount,
    this.subtotal = 0,
    this.tax = 0,
    this.platformFee = 0,
    this.tip = 0,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryTime,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.paymentId,
    required this.createdAt,
    this.isPaused = false,
    this.deliverySlotId = '',
    this.mealType = 'lunch',
    this.items = const [],
  });

  bool get isOneTimeOrder => orderType == 'one_time';
  bool get isSubscriptionOrder => orderType == 'subscription';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'kitchen': kitchenId,
      'order_type': orderType,
      'plan': planId.isNotEmpty ? planId : null,
      'plan_name': planName,
      'amount': amount.toString(),
      'subtotal': subtotal.toString(),
      'tax': tax.toString(),
      'platform_fee': platformFee.toString(),
      'tip': tip.toString(),
      'delivery_address': deliveryAddress,
      if (deliveryLatitude != null) 'delivery_latitude': deliveryLatitude.toString(),
      if (deliveryLongitude != null) 'delivery_longitude': deliveryLongitude.toString(),
      'status': status,
      'payment_id': paymentId,
      'delivery_slot_id': deliverySlotId,
      'meal_type': mealType,
    };
    if (deliveryTime != null) {
      map['delivery_time'] = deliveryTime!.toIso8601String();
    }
    if (startDate != endDate) {
      map['start_date'] = startDate.toIso8601String().split('T')[0];
      map['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    return map;
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(String key) {
      final val = map[key];
      if (val is String && val.isNotEmpty) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    final kitchenDetails = map['kitchen_details'] as Map<String, dynamic>?;
    final customerDetails = map['customer_details'] as Map<String, dynamic>?;
    final itemsList = (map['items'] as List<dynamic>?)
            ?.map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return OrderModel(
      id: docId,
      customerId: (map['customer'] ?? map['customerId'] ?? '').toString(),
      customerName: customerDetails?['name'] as String? ?? map['customerName'] ?? '',
      kitchenId: (map['kitchen'] ?? map['kitchenId'] ?? '').toString(),
      kitchenName: kitchenDetails?['name'] as String? ?? map['kitchenName'] ?? '',
      chefId: (kitchenDetails?['chef'] ?? '').toString(),
      chefName: (kitchenDetails?['chef_details']?['name'] as String?) ?? '',
      orderType: map['order_type'] ?? map['orderType'] ?? 'subscription',
      planId: (map['plan'] ?? map['planId'] ?? '').toString(),
      planName: map['plan_name'] ?? map['planName'] ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(map['subtotal']?.toString() ?? '0') ?? 0.0,
      tax: double.tryParse(map['tax']?.toString() ?? '0') ?? 0.0,
      platformFee: double.tryParse(map['platform_fee']?.toString() ?? '0') ?? 0.0,
      tip: double.tryParse(map['tip']?.toString() ?? '0') ?? 0.0,
      deliveryAddress: map['delivery_address'] ?? map['deliveryAddress'] ?? '',
      deliveryLatitude: map['delivery_latitude'] != null ? double.tryParse(map['delivery_latitude'].toString()) : null,
      deliveryLongitude: map['delivery_longitude'] != null ? double.tryParse(map['delivery_longitude'].toString()) : null,
      deliveryTime: map['delivery_time'] != null ? parseDate('delivery_time') : null,
      startDate: parseDate('start_date'),
      endDate: parseDate('end_date'),
      status: map['status'] ?? 'pending',
      paymentId: map['payment_id'] ?? map['paymentId'] ?? '',
      createdAt: parseDate('created_at'),
      isPaused: map['is_paused'] ?? map['isPaused'] ?? false,
      deliverySlotId: map['delivery_slot_id'] ?? map['deliverySlotId'] ?? '',
      mealType: map['meal_type'] ?? map['mealType'] ?? 'lunch',
      items: itemsList,
    );
  }
}
