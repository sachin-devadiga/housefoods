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
      'kitchenId': kitchenId,
      'date': DateTime(date.year, date.month, date.day), // Standardize to midnight
      'mealTitle': mealTitle,
      'description': description,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
    };
  }

  factory DailyMenuModel.fromMap(Map<String, dynamic> map, String docId) {
    return DailyMenuModel(
      id: docId,
      kitchenId: map['kitchenId'] ?? '',
      date: map['date'] as DateTime,
      mealTitle: map['mealTitle'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isVeg: map['isVeg'] ?? true,
    );
  }
}
