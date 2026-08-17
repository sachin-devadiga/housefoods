import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../support/presentation/providers/support_provider.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().fetchAllTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Support Tickets"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SupportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.allTickets.isEmpty) {
            return const Center(child: Text("No support tickets found."));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchAllTickets(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.allTickets.length,
              itemBuilder: (context, index) {
                final ticket = provider.allTickets[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ticket['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            _buildStatusChip(ticket['status'] ?? ''),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Customer: ${ticket['user_details']?['name'] ?? ticket['user'] ?? 'User'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Divider(height: 24),
                        Text(ticket['message'] ?? '', style: const TextStyle(height: 1.4)),
                        const SizedBox(height: 16),
                        Text(
                          "Received: ${DateFormat('dd MMM, hh:mm a').format(DateTime.parse(ticket['created_at'].toString()))}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (ticket['status'] == 'open')
                              TextButton(
                                onPressed: () => provider.updateTicketStatus(ticket['id'], 'in_progress'),
                                child: const Text("Mark In-Progress"),
                              ),
                            const SizedBox(width: 8),
                            if (ticket['status'] != 'resolved')
                              ElevatedButton(
                                onPressed: () => provider.updateTicketStatus(ticket['id'], 'resolved'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text("Mark Resolved"),
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'resolved': color = Colors.green; break;
      case 'in_progress': color = Colors.orange; break;
      default: color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
