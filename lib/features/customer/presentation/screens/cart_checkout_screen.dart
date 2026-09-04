import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/address_model.dart';
import '../../../auth/presentation/screens/add_address_screen.dart';
import '../../../auth/presentation/screens/map_picker_screen.dart';
import '../../domain/models/cart_model.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';
import 'order_success_screen.dart';

class CartCheckoutScreen extends StatefulWidget {
  final String kitchenId;
  final String kitchenName;
  final List<CartItemModel> items;
  final double subtotal;

  const CartCheckoutScreen({
    super.key,
    required this.kitchenId,
    required this.kitchenName,
    required this.items,
    required this.subtotal,
  });

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  UserModel? _user;
  AddressModel? _selectedAddress;
  bool _isUserLoading = true;
  bool _isProcessing = false;
  int _selectedSlot = 0;
  final _tipController = TextEditingController();

  static const List<String> _deliverySlots = [
    'ASAP (30-45 min)',
    '12:00 PM - 1:00 PM',
    '1:00 PM - 2:00 PM',
    '7:00 PM - 8:00 PM',
    '8:00 PM - 9:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firebaseUid = authProvider.userProfile?['uid'] ?? '';
    if (firebaseUid.isNotEmpty) {
      final userData = await UserRepositoryImpl().getUser(firebaseUid);
      if (mounted) {
        setState(() {
          _user = userData;
          _isUserLoading = false;
          if (_user != null && _user!.addresses.isNotEmpty) {
            _selectedAddress = _user!.addresses.first;
          }
        });
      }
    } else {
      setState(() => _isUserLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final total = widget.subtotal;
    final tip = double.tryParse(_tipController.text) ?? 0;
    final grandTotal = total + tip;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Order Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(widget.kitchenName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    ...widget.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${item.quantity}x ${item.menuItemName}'),
                          ),
                          Text('₹${item.itemTotal.toStringAsFixed(0)}'),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Delivery Address'),
            Card(
              child: _selectedAddress == null
                  ? Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add_location_alt),
                          title: const Text('Add delivery address'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            if (_user == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!)),
                            );
                            _loadUser();
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.map, color: AppTheme.primaryColor),
                          title: const Text('Select on Map'),
                          subtitle: const Text('Pick exact delivery location', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _pickAddressFromMap,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                          title: Text(_selectedAddress!.fullAddress),
                          subtitle: Text(_selectedAddress!.label),
                          trailing: TextButton(
                            onPressed: () => _showAddressPicker(),
                            child: const Text('Change'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.map, size: 20),
                          title: const Text('Select on Map', style: TextStyle(fontSize: 13)),
                          onTap: _pickAddressFromMap,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Delivery Time'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: List.generate(_deliverySlots.length, (index) {
                    return RadioListTile<int>(
                      value: index,
                      // ignore: deprecated_member_use
                      groupValue: _selectedSlot,
                      // ignore: deprecated_member_use
                      onChanged: (val) => setState(() => _selectedSlot = val ?? 0),
                      title: Text(_deliverySlots[index]),
                      activeColor: AppTheme.primaryColor,
                      dense: true,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Tip for Delivery Partner'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tipController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: '₹ ',
                          hintText: '0',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Optional', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Bill Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _billRow('Item Total', '₹${widget.subtotal.toStringAsFixed(0)}'),
                    _billRow('Delivery Fee', 'FREE', isGreen: true),
                    _billRow('Tip', '₹${tip.toStringAsFixed(0)}'),
                    const Divider(),
                    _billRow('Grand Total', '₹${grandTotal.toStringAsFixed(0)}', isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isProcessing ? null : () => _processOrder(grandTotal, tip),
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text('Pay ₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _billRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddressPicker() {
    if (_user == null || _user!.addresses.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._user!.addresses.map((addr) => ListTile(
            leading: Radio<AddressModel>(
              value: addr,
              // ignore: deprecated_member_use
              groupValue: _selectedAddress,
              // ignore: deprecated_member_use
              onChanged: (val) {
                setState(() => _selectedAddress = val);
                Navigator.pop(ctx);
              },
              activeColor: AppTheme.primaryColor,
            ),
            title: Text(addr.fullAddress),
            subtitle: Text(addr.label),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _pickAddressFromMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final addr = result['address'] as String? ?? '';
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;
      if (addr.isNotEmpty) {
        setState(() {
          _selectedAddress = AddressModel(
            id: 'map_${DateTime.now().millisecondsSinceEpoch}',
            label: 'Map Location',
            fullAddress: addr,
            houseNo: '',
            landmark: '',
            latitude: lat,
            longitude: lng,
          );
        });
      }
    }
  }

  Future<void> _processOrder(double total, double tip) async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profile = authProvider.userProfile;
      final email = profile?['email'] ?? 'customer@mealin.com';
      final phone = profile?['phone'] ?? '';
      final uid = profile?['uid'] ?? '';

      final itemsData = widget.items.map((item) => {
        'menu_item': int.tryParse(item.menuItemId) ?? 0,
        'quantity': item.quantity,
        'special_instructions': item.specialInstructions,
      }).toList();

      final order = OrderModel(
        id: '',
        customerId: uid,
        kitchenId: widget.kitchenId,
        kitchenName: widget.kitchenName,
        amount: total,
        deliveryAddress: _selectedAddress!.fullAddress,
        deliveryLatitude: _selectedAddress!.latitude,
        deliveryLongitude: _selectedAddress!.longitude,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        status: 'active',
        paymentId: '',
        createdAt: DateTime.now(),
        orderType: 'one_time',
      );

      orderProvider.openCheckoutForOneTime(
        order: order,
        items: itemsData,
        tip: tip,
        userEmail: email,
        userPhone: phone,
        onSuccess: (finalOrder) async {
          await cartProvider.clearCart();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: finalOrder)),
              (route) => route.isFirst,
            );
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
