class DishModel {
  final String id;
  final String kitchenId;
  final String name;
  final String description;
  final String imageUrl;
  final bool isVeg;

  DishModel({
    required this.id,
    required this.kitchenId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isVeg,
  });

  Map<String, dynamic> toMap() {
    return {
      'kitchenId': kitchenId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'isVeg': isVeg,
    };
  }

  factory DishModel.fromMap(Map<String, dynamic> map, String docId) {
    return DishModel(
      id: docId,
      kitchenId: map['kitchenId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isVeg: map['isVeg'] ?? true,
    );
  }
}
