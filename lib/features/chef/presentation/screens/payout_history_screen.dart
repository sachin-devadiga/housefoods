import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/chef_provider.dart';

class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChefProvider>().fetchPayoutHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Withdrawal History"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ChefProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.payoutHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.payoutHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "No payout records found",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchPayoutHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.payoutHistory.length,
              itemBuilder: (context, index) {
                final request = provider.payoutHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                              "₹${(request['amount'] ?? 0.0).toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            _buildStatusBadge(request['status'] ?? ''),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildInfoRow("Bank", _mapValue(request, 'bank_name', 'bankName')),
                        _buildInfoRow("Account", "****${_maskAccount(_mapValue(request, 'account_number', 'accountNumber'))}"),
                        _buildInfoRow("Requested", _formatDate(_mapValue(request, 'requested_at', 'requestedAt'))),
                        if ((request['status'] ?? '') == 'paid' || (request['status'] ?? '') == 'approved')
                          _buildInfoRow("Processed", _formatDate(_mapValue(request, 'processed_at', 'processedAt')), 
                                        isBold: true, color: Colors.green),
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

  String _mapValue(Map<String, dynamic> map, String snakeKey, String camelKey) {
    return (map[snakeKey] ?? map[camelKey] ?? '').toString();
  }

  String _maskAccount(String acc) {
    if (acc.length < 4) return acc;
    return acc.substring(acc.length - 4);
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) return DateFormat('dd MMM yyyy').format(date);
    final parsed = DateTime.tryParse(date.toString());
    if (parsed != null) return DateFormat('dd MMM yyyy').format(parsed);
    return date.toString();
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
