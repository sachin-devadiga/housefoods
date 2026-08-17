import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class VerifyDeliveryPartnersScreen extends StatefulWidget {
  const VerifyDeliveryPartnersScreen({super.key});

  @override
  State<VerifyDeliveryPartnersScreen> createState() => _VerifyDeliveryPartnersScreenState();
}

class _VerifyDeliveryPartnersScreenState extends State<VerifyDeliveryPartnersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchPendingDocuments();
    });
  }

  void _showDocumentDialog(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${_docLabel(doc['doc_type'])} — ${doc['user_name'] ?? 'User'}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((doc['doc_number'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("Number: ${doc['doc_number']}", style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            if ((doc['file_url'] ?? '').isNotEmpty)
              Image.network(doc['file_url'], height: 200, width: double.infinity, fit: BoxFit.cover)
            else
              const Text("No file uploaded", style: TextStyle(color: Colors.grey)),
            if ((doc['verification_notes'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("Notes: ${doc['verification_notes']}", style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AdminProvider>().updateDocumentStatus(doc['id'], 'rejected', notes: 'Rejected by admin');
              Navigator.pop(context);
            },
            child: const Text("Reject", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AdminProvider>().updateDocumentStatus(doc['id'], 'verified');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  String _docLabel(String? type) {
    switch (type) {
      case 'aadhar': return 'Aadhar Card';
      case 'pan': return 'PAN Card';
      case 'driving_license': return 'Driving License';
      default: return type ?? 'Document';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rider Document Verification"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.pendingDocuments.isEmpty) {
            return const Center(child: Text("No pending documents to review"));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchPendingDocuments(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pendingDocuments.length,
              itemBuilder: (context, index) {
                final doc = provider.pendingDocuments[index];
                final userName = doc['user_name'] ?? doc['user'] ?? 'User';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(_docIcon(doc['doc_type']), color: Colors.orange),
                    ),
                    title: Text(_docLabel(doc['doc_type']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Rider: $userName", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        if ((doc['doc_number'] ?? '').isNotEmpty)
                          Text("No: ${doc['doc_number']}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showDocumentDialog(doc),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _docIcon(String? type) {
    switch (type) {
      case 'aadhar': return Icons.badge;
      case 'pan': return Icons.credit_card;
      case 'driving_license': return Icons.drive_eta;
      default: return Icons.description;
    }
  }
}
