import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';

class DeliveryDocumentUploadScreen extends StatefulWidget {
  const DeliveryDocumentUploadScreen({super.key});

  @override
  State<DeliveryDocumentUploadScreen> createState() => _DeliveryDocumentUploadScreenState();
}

class _DeliveryDocumentUploadScreenState extends State<DeliveryDocumentUploadScreen> {
  late ApiService _api;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;

  List<Map<String, dynamic>> _documents = [];

  static const List<Map<String, dynamic>> _docTypes = [
    {'type': 'aadhar', 'label': 'Aadhar Card', 'icon': Icons.badge, 'numberLabel': 'Aadhar Number'},
    {'type': 'pan', 'label': 'PAN Card', 'icon': Icons.credit_card, 'numberLabel': 'PAN Number'},
    {'type': 'driving_license', 'label': 'Driving License', 'icon': Icons.drive_eta, 'numberLabel': 'License Number'},
  ];

  final Map<String, TextEditingController> _numberControllers = {};
  final Map<String, bool> _uploading = {};

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
    for (final dt in _docTypes) {
      _numberControllers[dt['type'] as String] = TextEditingController();
      _uploading[dt['type'] as String] = false;
    }
    _loadDocuments();
  }

  @override
  void dispose() {
    _api.dispose();
    for (final c in _numberControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.get(AppConstants.deliveryDocumentsEndpoint);
      final docs = data['data'] as List? ?? [];
      _documents = docs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final doc in _documents) {
        final type = doc['doc_type'] as String?;
        final numCtrl = _numberControllers[type];
        if (numCtrl != null && numCtrl.text.isEmpty && doc['doc_number'] != null) {
          numCtrl.text = doc['doc_number'].toString();
        }
      }
    } catch (e) {
      debugPrint("Error loading documents: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Map<String, dynamic>? _getDocForType(String type) {
    try {
      return _documents.firstWhere((d) => d['doc_type'] == type);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAndUpload(String docType) async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _uploading[docType] = true);
    try {
      final url = await _api.uploadFile(AppConstants.uploadEndpoint, picked.path);
      final docNumber = _numberControllers[docType]?.text.trim() ?? '';
      await _api.post(
        AppConstants.deliveryDocumentUploadEndpoint,
        body: {
          'doc_type': docType,
          'doc_number': docNumber,
          'file_url': url,
        },
      );
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload document')),
        );
      }
    }
    if (mounted) setState(() => _uploading[docType] = false);
  }

  Future<void> _deleteDocument(int id) async {
    try {
      await _api.delete('${AppConstants.deliveryDocumentDeleteEndpoint}/$id/delete/');
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Widget _buildStatusChip(String? status) {
    if (status == null) return const SizedBox.shrink();
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'verified':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Verified';
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Rejected';
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> docType) {
    final type = docType['type'] as String;
    final label = docType['label'] as String;
    final icon = docType['icon'] as IconData;
    final numberLabel = docType['numberLabel'] as String;
    final existing = _getDocForType(type);
    final status = existing?['status'] as String?;
    final fileUrl = existing?['file_url'] as String? ?? '';
    final verificationNotes = existing?['verification_notes'] as String? ?? '';
    final hasFile = fileUrl.isNotEmpty;
    final isUploading = _uploading[type] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                if (status != null) _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numberControllers[type],
              decoration: InputDecoration(
                labelText: numberLabel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Enter $numberLabel',
                isDense: true,
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isUploading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  if (hasFile)
                    TextButton.icon(
                      onPressed: () => _pickAndUpload(type),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change Photo'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _pickAndUpload(type),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Upload Photo'),
                    ),
                  const Spacer(),
                  if (existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteDocument(existing['id'] as int),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ],
            ),
            if (verificationNotes.isNotEmpty && status == 'rejected')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reason: $verificationNotes',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Verification')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDocuments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Upload your Aadhar Card and PAN Card. '
                              'Admin will verify and approve your documents.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._docTypes.map((dt) => _buildDocumentCard(dt)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadDocuments,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Status'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
