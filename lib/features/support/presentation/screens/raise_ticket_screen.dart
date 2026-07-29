import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/ticket_model.dart';
import '../providers/support_provider.dart';

class RaiseTicketScreen extends StatefulWidget {
  final String? orderId;
  const RaiseTicketScreen({super.key, this.orderId});

  @override
  State<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends State<RaiseTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Quality';

  final List<String> _categories = [
    'Quality',
    'Delivery',
    'Payment',
    'App Issue',
    'Other'
  ];

  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profile = authProvider.userProfile;
      if (profile == null) return;

      final uid = profile['uid'] ?? '';
      final name = profile['name'] ?? 'Customer';

      final ticket = SupportTicketModel(
        id: '',
        userId: uid,
        userName: name,
        orderId: widget.orderId,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        status: 'open',
        createdAt: DateTime.now(),
      );

      try {
        await context.read<SupportProvider>().raiseTicket(ticket.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ticket raised successfully. We will get back to you soon."),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Raise Support Ticket")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "How can we help you?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Select a category and describe your issue.",
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              
              const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              
              const SizedBox(height: 24),
              const Text("Description", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Provide details about your problem...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              ),
              
              const SizedBox(height: 40),
              context.watch<SupportProvider>().isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitTicket,
                      child: const Text("Submit Ticket"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
