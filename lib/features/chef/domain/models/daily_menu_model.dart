class DailyMenuModel {
  final String id;
  final String kitchenId;
  final DateTime date;
  final String mealTitle;
  final String description;
  final String imageUrl;
  final bool isVeg;

  DailyMenuModel({
    required this.id,
    required this.kitchenId,
    required this.date,
    required this.mealTitle,
    required this.description,
    required this.imageUrl,
    required this.isVeg,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'mealTitle': mealTitle,
      'description': description,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
    };
  }

  factory DailyMenuModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawDate = map['date']?.toString() ?? '';
    return DailyMenuModel(
      id: docId,
      kitchenId: map['kitchenId'] ?? map['kitchen'] ?? '',
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      mealTitle: map['mealTitle'] ?? map['meal_title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? map['image_url'] ?? '',
      isVeg: map['isVeg'] ?? map['is_veg'] ?? true,
    );
  }
}
