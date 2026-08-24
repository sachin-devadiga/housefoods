class OrderItemModel {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String menuItemImage;
  final int quantity;
  final double priceAtOrder;
  final String specialInstructions;

  OrderItemModel({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.menuItemImage,
    required this.quantity,
    required this.priceAtOrder,
    required this.specialInstructions,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: '${map['id'] ?? ''}',
      menuItemId: '${map['menu_item'] ?? ''}',
      menuItemName: map['menu_item_name'] ?? '',
      menuItemImage: map['menu_item_image'] ?? '',
      quantity: map['quantity'] ?? 1,
      priceAtOrder: (map['price_at_order'] ?? 0.0).toDouble(),
      specialInstructions: map['special_instructions'] ?? '',
    );
  }
}
