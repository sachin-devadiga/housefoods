class CartItemModel {
  final String id;
  final String menuItemId;
  final String menuItemName;
  final String menuItemImage;
  final double menuItemPrice;
  final int quantity;
  final String specialInstructions;
  final double itemTotal;

  CartItemModel({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.menuItemImage,
    required this.menuItemPrice,
    required this.quantity,
    required this.specialInstructions,
    required this.itemTotal,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      id: '${map['id'] ?? ''}',
      menuItemId: '${map['menu_item'] ?? ''}',
      menuItemName: map['menu_item_name'] ?? '',
      menuItemImage: map['menu_item_image'] ?? '',
      menuItemPrice: (map['menu_item_price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      specialInstructions: map['special_instructions'] ?? '',
      itemTotal: (map['item_total'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_item': menuItemId,
      'quantity': quantity,
      'special_instructions': specialInstructions,
    };
  }
}

class CartModel {
  final String id;
  final String? kitchenId;
  final String? kitchenName;
  final List<CartItemModel> items;
  final int totalItemCount;
  final double subtotal;

  CartModel({
    required this.id,
    this.kitchenId,
    this.kitchenName,
    required this.items,
    required this.totalItemCount,
    required this.subtotal,
  });

  factory CartModel.fromMap(Map<String, dynamic> map) {
    return CartModel(
      id: '${map['id'] ?? ''}',
      kitchenId: map['kitchen']?.toString(),
      kitchenName: map['kitchen_name'],
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => CartItemModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalItemCount: map['total_item_count'] ?? 0,
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}
