import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';

class DeliveryPayoutScreen extends StatefulWidget {
  const DeliveryPayoutScreen({super.key});

  @override
  State<DeliveryPayoutScreen> createState() => _DeliveryPayoutScreenState();
}

class _DeliveryPayoutScreenState extends State<DeliveryPayoutScreen> {
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    context.read<DeliveryPartnerProvider>().fetchPayoutHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw Earnings')),
      body: Consumer<DeliveryPartnerProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${provider.availableBalance.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Request Withdrawal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final amt = double.tryParse(v ?? '') ?? 0;
                          if (amt < 100) return 'Minimum ₹100';
                          if (amt > provider.availableBalance) return 'Insufficient balance';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ifscController,
                        decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isLoading ? null : _submitPayout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: provider.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Request Payout', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Payout History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (provider.payoutHistory.isEmpty)
                  const Center(child: Text('No payout requests yet', style: TextStyle(color: Colors.grey)))
                else
                  ...provider.payoutHistory.map((p) => Card(
                    child: ListTile(
                      leading: Icon(
                        p['status'] == 'paid' ? Icons.check_circle : p['status'] == 'approved' ? Icons.approval : Icons.pending,
                        color: p['status'] == 'paid' ? Colors.green : p['status'] == 'approved' ? Colors.blue : Colors.orange,
                      ),
                      title: Text('₹${p['amount']}'),
                      subtitle: Text(p['status'].toString().toUpperCase()),
                      trailing: Text(
                        p['requested_at']?.toString().substring(0, 10) ?? '',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _submitPayout() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<DeliveryPartnerProvider>();
    provider.requestPayout(
      double.parse(_amountController.text),
      {
        'bank_name': _bankNameController.text,
        'account_number': _accountController.text,
        'ifsc_code': _ifscController.text,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payout request submitted')),
    );
    Navigator.pop(context);
  }
}
