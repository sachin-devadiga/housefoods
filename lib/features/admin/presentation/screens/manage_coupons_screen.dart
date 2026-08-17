import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class ManageCouponsScreen extends StatefulWidget {
  const ManageCouponsScreen({super.key});

  @override
  State<ManageCouponsScreen> createState() => _ManageCouponsScreenState();
}

class _ManageCouponsScreenState extends State<ManageCouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCoupons();
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? existing}) {
    final codeController = TextEditingController(text: existing?['code'] ?? '');
    final discountController = TextEditingController(text: (existing?['discount_percentage'] ?? existing?['discount'] ?? '').toString());
    final minOrderController = TextEditingController(text: (existing?['min_order_amount'] ?? existing?['min_order'] ?? 0).toString());
    final maxDiscountController = TextEditingController(text: (existing?['max_discount_amount'] ?? existing?['max_discount'] ?? '').toString());
    final usageLimitController = TextEditingController(text: (existing?['usage_limit'] ?? 0).toString());
    final expiryController = TextEditingController(text: existing?['expiry_date'] ?? existing?['valid_until'] ?? '');
    bool isActive = existing?['is_active'] ?? true;
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Coupon' : 'Add Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Coupon Code',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'e.g. SAVE20',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  decoration: InputDecoration(
                    labelText: 'Discount %',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderController,
                  decoration: InputDecoration(
                    labelText: 'Min Order Amount (₹)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxDiscountController,
                  decoration: InputDecoration(
                    labelText: 'Max Discount (₹) (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usageLimitController,
                  decoration: InputDecoration(
                    labelText: 'Usage Limit (0 = unlimited)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryController,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'code': codeController.text.trim().toUpperCase(),
                  'discount_percentage': double.tryParse(discountController.text) ?? 0,
                  'min_order_amount': double.tryParse(minOrderController.text) ?? 0,
                  'max_discount_amount': double.tryParse(maxDiscountController.text) ?? 0,
                  'usage_limit': int.tryParse(usageLimitController.text) ?? 0,
                  'expiry_date': expiryController.text.trim(),
                  'is_active': isActive,
                };
                if ((data['code'] as String).isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coupon code is required')),
                  );
                  return;
                }
                final provider = context.read<AdminProvider>();
                if (isEdit) {
                  await provider.updateCoupon(existing['id'], data);
                } else {
                  await provider.addCoupon(data);
                }
                if (mounted) Navigator.pop(ctx);
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> coupon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Delete coupon "${coupon['code']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AdminProvider>().deleteCoupon(coupon['id']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Coupons')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.coupons.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.coupons.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.discount, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No coupons yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchCoupons(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.coupons.length,
              itemBuilder: (context, index) {
                final coupon = provider.coupons[index];
                final isActive = coupon['is_active'] ?? true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.discount, color: isActive ? AppTheme.primaryColor : Colors.grey, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(coupon['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '${coupon['discount_percentage'] ?? coupon['discount'] ?? 0}% off | Min ₹${coupon['min_order_amount'] ?? coupon['min_order'] ?? 0}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                              if (coupon['expiry_date'] != null || coupon['valid_until'] != null)
                                Text(
                                  'Expires: ${coupon['expiry_date'] ?? coupon['valid_until'] ?? ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(isActive ? Icons.check_circle : Icons.cancel, color: isActive ? Colors.green : Colors.red, size: 20),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                              onPressed: () => _showAddEditDialog(existing: coupon),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(coupon),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
