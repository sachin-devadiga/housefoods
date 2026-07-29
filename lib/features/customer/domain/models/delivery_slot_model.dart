class DeliverySlotModel {
  final String id;
  final String title; // e.g. "Morning Lunch"
  final String timeRange; // e.g. "12:00 PM - 01:30 PM"
  final String mealType; // 'lunch', 'dinner'

  DeliverySlotModel({
    required this.id,
    required this.title,
    required this.timeRange,
    required this.mealType,
  });
}

final List<DeliverySlotModel> availableSlots = [
  DeliverySlotModel(id: 'l1', title: 'Early Lunch', timeRange: '12:00 PM - 01:00 PM', mealType: 'lunch'),
  DeliverySlotModel(id: 'l2', title: 'Late Lunch', timeRange: '01:00 PM - 02:30 PM', mealType: 'lunch'),
  DeliverySlotModel(id: 'd1', title: 'Early Dinner', timeRange: '07:00 PM - 08:30 PM', mealType: 'dinner'),
  DeliverySlotModel(id: 'd2', title: 'Late Dinner', timeRange: '08:30 PM - 10:00 PM', mealType: 'dinner'),
];
