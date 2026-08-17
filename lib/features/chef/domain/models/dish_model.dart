class DishModel {
  final String id;
  final String kitchenId;
  final String name;
  final String description;
  final String imageUrl;
  final bool isVeg;
  final double price;

  DishModel({
    required this.id,
    required this.kitchenId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isVeg,
    this.price = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'kitchenId': kitchenId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
      'price': price,
    };
  }

  factory DishModel.fromMap(Map<String, dynamic> map, String docId) {
    return DishModel(
      id: docId,
      kitchenId: map['kitchenId'] ?? map['kitchen'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? map['image_url'] ?? '',
      isVeg: map['isVeg'] ?? map['is_veg'] ?? true,
      price: (map['price'] ?? 0.0).toDouble(),
    );
  }
}
