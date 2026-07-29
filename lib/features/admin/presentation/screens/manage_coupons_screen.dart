import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/models/coupon_model.dart';
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

  void _showAddCouponDialog() {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final minOrderController = TextEditingController();
    String discountType = 'flat';
    DateTime expiryDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create New Coupon", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: "Promo Code (e.g. SAVE50)", border: OutlineInputBorder()),
                textCapitalization: TextSelectionControls as dynamic == TextCapitalization.characters ? TextCapitalization.characters : TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: discountType,
                      decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'flat', child: Text("Flat Amount")),
                        DropdownMenuItem(value: 'percentage', child: Text("Percentage")),
                      ],
                      onChanged: (val) => setModalState(() => discountType = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: discountType == 'flat' ? "Value (₹)" : "Value (%)",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minOrderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Min Order Value (₹)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Expiry Date"),
                subtitle: Text(DateFormat('dd MMM yyyy').format(expiryDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expiryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => expiryDate = picked);
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  final coupon = CouponModel(
                    id: '',
                    code: codeController.text.trim(),
                    discountType: discountType,
                    discountValue: double.tryParse(valueController.text) ?? 0,
                    minOrderValue: double.tryParse(minOrderController.text) ?? 0,
                    expiryDate: expiryDate,
                  );
                  context.read<AdminProvider>().addCoupon(coupon.toMap());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: const Text("Launch Coupon"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Coupons"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());

          if (provider.coupons.isEmpty) {
            return const Center(child: Text("No active coupons found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.coupons.length,
            itemBuilder: (context, index) {
              final coupon = provider.coupons[index];
              return Card(
                child: ListTile(
                  title: Text(coupon['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                    "${coupon['discount_type'] == 'flat' ? '₹' : ''}${coupon['discount_value']}${coupon['discount_type'] == 'percentage' ? '%' : ''} OFF\nMin Order: ₹${coupon['min_order_value']}\nExpires: ${DateFormat('dd MMM yyyy').format(DateTime.parse(coupon['expiry_date'].toString()))}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => provider.deleteCoupon(coupon['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCouponDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
