import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore_for_file: deprecated_member_use
import '../../../../core/theme/app_theme.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/models/address_model.dart';
import '../../../auth/presentation/screens/add_address_screen.dart';
import '../../domain/models/cart_model.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';
import 'order_success_screen.dart';

enum _PayMode { online, cod }

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
  _PayMode _payMode = _PayMode.online;
  double _tip = 0;
  final _couponController = TextEditingController();
  bool _isCouponWorking = false;
  String? _couponError;

  static const List<double> _tipOptions = [0, 10, 20, 30];

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Start with a clean slate so stale discounts from other flows don't leak in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().removeCoupon();
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
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

  double _payableBase(OrderProvider orderProvider) {
    final value = widget.subtotal -
        orderProvider.discountAmount -
        (orderProvider.isWalletApplied ? orderProvider.walletRedemptionAmount : 0);
    return value < 0 ? 0 : value;
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    setState(() {
      _isCouponWorking = true;
      _couponError = null;
    });
    try {
      await orderProvider.applyCoupon(code, widget.subtotal);
      if (!mounted) return;
      if (orderProvider.appliedCoupon == null) {
        setState(() => _couponError = 'Coupon applied with no discount');
      }
    } catch (e) {
      if (mounted) setState(() => _couponError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isCouponWorking = false);
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

    final orderProvider = context.watch<OrderProvider>();
    final payable = _payableBase(orderProvider);
    final grandTotal = payable + _tip;
    final walletBalance = _user?.walletBalance ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEtaAddressCard(),
            const SizedBox(height: 16),
            _buildItemsCard(),
            const SizedBox(height: 16),
            _buildPaymentCard(),
            const SizedBox(height: 16),
            _buildOffersCard(orderProvider),
            if (walletBalance > 0) ...[
              const SizedBox(height: 16),
              _buildWalletCard(orderProvider, walletBalance, payable),
            ],
            const SizedBox(height: 16),
            _buildTipCard(),
            const SizedBox(height: 16),
            _buildBillCard(orderProvider, payable, grandTotal),
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
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isProcessing ? null : () => _placeOrder(payable, grandTotal),
          child: _isProcessing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _payMode == _PayMode.cod
                      ? 'Place Order • ₹${grandTotal.toStringAsFixed(0)}'
                      : 'Pay ₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
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

  Widget _buildEtaAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delivery_dining, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery in 30–40 mins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('From ${widget.kitchenName}', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: _buildAddressBody()),
                TextButton(
                  onPressed: () => _selectedAddress == null ? _addAddressFlow() : _showAddressPicker(),
                  child: Text(_selectedAddress == null ? 'Add' : 'Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressBody() {
    final addr = _selectedAddress;
    if (addr == null) {
      return const Text('No delivery address added yet',
          style: TextStyle(fontWeight: FontWeight.w600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(addr.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(addr.fullAddress, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.kitchenName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text('${widget.items.length} item${widget.items.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            ...widget.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 1.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Center(
                          child: Icon(Icons.circle, size: 6, color: Colors.green),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${item.quantity} x ${item.menuItemName}')),
                      Text('₹${item.itemTotal.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Payment Method'),
        Card(
          child: Column(
            children: [
              RadioListTile<_PayMode>(
                value: _PayMode.online,
                groupValue: _payMode,
                onChanged: (v) => setState(() => _payMode = v ?? _PayMode.online),
                activeColor: AppTheme.primaryColor,
                title: const Text('UPI / Card / Netbanking', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pay securely online', style: TextStyle(fontSize: 12)),
                secondary: const Icon(Icons.smartphone, color: AppTheme.primaryColor),
                dense: true,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              RadioListTile<_PayMode>(
                value: _PayMode.cod,
                groupValue: _payMode,
                onChanged: (v) => setState(() => _payMode = v ?? _PayMode.online),
                activeColor: AppTheme.primaryColor,
                title: const Text('Cash on Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pay at your doorstep', style: TextStyle(fontSize: 12)),
                secondary: const Icon(Icons.payments_outlined, color: Colors.green),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOffersCard(OrderProvider orderProvider) {
    final applied = orderProvider.appliedCoupon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Offers'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: applied == null
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'Enter coupon code',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.local_offer_outlined),
                              ),
                              onSubmitted: (_) => _applyCoupon(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isCouponWorking ? null : _applyCoupon,
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                            child: _isCouponWorking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Apply', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      if (_couponError != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_couponError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${applied['code'] ?? 'Coupon'} applied',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'You save ₹${orderProvider.discountAmount.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          orderProvider.removeCoupon();
                          _couponController.clear();
                          setState(() {});
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(OrderProvider orderProvider, double balance, double payable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HouseCredits'),
        Card(
          child: SwitchListTile(
            value: orderProvider.isWalletApplied,
            onChanged: (v) {
              orderProvider.toggleWallet(v, payable, balance);
            },
            activeThumbColor: AppTheme.primaryColor,
            title: Text('Use ₹${balance.toStringAsFixed(0)} available',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: orderProvider.isWalletApplied
                ? Text('₹${orderProvider.walletRedemptionAmount.toStringAsFixed(0)} will be used',
                    style: const TextStyle(color: Colors.green, fontSize: 12))
                : const Text('Pay partly with wallet balance', style: TextStyle(fontSize: 12)),
            secondary: const Icon(Icons.account_balance_wallet_outlined, color: Colors.deepPurple),
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tip your delivery partner'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              children: _tipOptions.map((t) {
                final selected = _tip == t;
                return ChoiceChip(
                  label: Text(t == 0 ? 'No tip' : '₹${t.toStringAsFixed(0)}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _tip = t),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  side: BorderSide(color: selected ? AppTheme.primaryColor : Colors.grey.shade300),
                  labelStyle: TextStyle(
                    color: selected ? AppTheme.primaryColor : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillCard(OrderProvider orderProvider, double payable, double grandTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Bill Details'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _billRow('Item Total', '₹${widget.subtotal.toStringAsFixed(0)}'),
                if (orderProvider.discountAmount > 0)
                  _billRow('Coupon Discount', '− ₹${orderProvider.discountAmount.toStringAsFixed(0)}',
                      isGreen: true),
                if (orderProvider.isWalletApplied && orderProvider.walletRedemptionAmount > 0)
                  _billRow('HouseCredits', '− ₹${orderProvider.walletRedemptionAmount.toStringAsFixed(0)}',
                      isGreen: true),
                _billRow('Delivery Fee', 'FREE', isGreen: true),
                _billRow('Tip', _tip > 0 ? '₹${_tip.toStringAsFixed(0)}' : '—'),
                const Divider(),
                _billRow('To Pay', '₹${grandTotal.toStringAsFixed(0)}', isBold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _billRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 15 : 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen ? Colors.green : null,
              fontSize: isBold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAddressFlow() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add an address')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!)),
    );
    _loadUser();
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
                  groupValue: _selectedAddress,
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

  Future<void> _placeOrder(double payable, double grandTotal) async {
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

      final itemsData = widget.items
          .map((item) => {
                'menu_item': int.tryParse(item.menuItemId) ?? item.menuItemId,
                'quantity': item.quantity,
                'special_instructions': item.specialInstructions,
              })
          .toList();

      if (_payMode == _PayMode.cod) {
        final walletCut = orderProvider.isWalletApplied ? orderProvider.walletRedemptionAmount : 0.0;
        try {
          final created = await orderProvider.placeCashOnDeliveryOrder(
            kitchenId: widget.kitchenId,
            kitchenName: widget.kitchenName,
            customerId: uid,
            amount: payable,
            deliveryAddress: _selectedAddress!.fullAddress,
            items: itemsData,
            tip: _tip,
            deliveryLatitude: _selectedAddress!.latitude,
            deliveryLongitude: _selectedAddress!.longitude,
            walletDeduction: walletCut,
          );
          await cartProvider.clearCart();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: created)),
              (route) => route.isFirst,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: AppTheme.errorColor),
            );
          }
        }
        return;
      }

      final order = OrderModel(
        id: '',
        customerId: uid,
        kitchenId: widget.kitchenId,
        kitchenName: widget.kitchenName,
        amount: payable,
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
        tip: _tip,
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
