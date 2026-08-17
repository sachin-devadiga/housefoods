import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';

class PayoutManagementScreen extends StatefulWidget {
  const PayoutManagementScreen({super.key});

  @override
  State<PayoutManagementScreen> createState() => _PayoutManagementScreenState();
}

class _PayoutManagementScreenState extends State<PayoutManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPendingPayouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Payouts"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.pendingPayouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No pending payout requests", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchPendingPayouts(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pendingPayouts.length,
              itemBuilder: (context, index) {
                final request = provider.pendingPayouts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              request['chef_details']?['name'] ?? 'Chef',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              "₹${(request['amount'] ?? 0).toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Requested on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(request['requested_at'].toString()))}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const Divider(height: 24),
                        const Text("Bank Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        _buildDetailRow("Bank", request['bank_details']?['bank_name'] ?? ''),
                        _buildDetailRow("Account No", request['bank_details']?['account_number'] ?? ''),
                        _buildDetailRow("IFSC", request['bank_details']?['ifsc_code'] ?? ''),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => provider.updatePayoutStatus(request['id'], 'rejected'),
                              child: const Text("Reject", style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => provider.updatePayoutStatus(request['id'], 'paid'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                              child: const Text("Mark as Paid"),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
