class MenuItemModel {
  final String id;
  final String kitchenId;
  final String? categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final bool isVeg;
  final int preparationTime;

  MenuItemModel({
    required this.id,
    required this.kitchenId,
    this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.isVeg,
    required this.preparationTime,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return MenuItemModel(
      id: docId,
      kitchenId: '${map['kitchen'] ?? ''}',
      categoryId: map['category']?.toString(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['image_url'] ?? map['imageUrl'] ?? '',
      isAvailable: map['is_available'] ?? map['isAvailable'] ?? true,
      isVeg: map['is_veg'] ?? map['isVeg'] ?? true,
      preparationTime: map['preparation_time'] ?? map['preparationTime'] ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kitchen': kitchenId,
      'category': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'is_veg': isVeg,
      'preparation_time': preparationTime,
    };
  }
}
