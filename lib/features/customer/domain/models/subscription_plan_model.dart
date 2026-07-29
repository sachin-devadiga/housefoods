class SubscriptionPlanModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final List<String> inclusions;
  final bool isVeg;
  final String imageUrl; // New field for meal photos

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.inclusions,
    required this.isVeg,
    required this.imageUrl,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map, String docId) {
    return SubscriptionPlanModel(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      durationDays: map['durationDays'] ?? 0,
      inclusions: List<String>.from(map['inclusions'] ?? []),
      isVeg: map['isVeg'] ?? true,
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'durationDays': durationDays,
      'inclusions': inclusions,
      'isVeg': isVeg,
      'imageUrl': imageUrl,
    };
  }
}
