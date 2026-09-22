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
    // Backend sets kitchen from the URL (perform_create), so never send
    // kitchen/kitchenId in the body — DRF rejects unknown fields.
    // Keys use snake_case to match MenuItemSerializer fields.
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'is_veg': isVeg,
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
