import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../features/customer/domain/models/kitchen_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chef_provider.dart';

class KitchenSetupScreen extends StatefulWidget {
  const KitchenSetupScreen({super.key});

  @override
  State<KitchenSetupScreen> createState() => _KitchenSetupScreenState();
}

class _KitchenSetupScreenState extends State<KitchenSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _fssaiController = TextEditingController();
  
  final List<String> _specialties = [];
  final LocationService _locationService = LocationService();
  
  String? _imageUrl;
  String? _idProofUrl;
  String? _licenseUrl;
  bool _isGettingLocation = false;

  void _addSpecialty() {
    if (_specialtyController.text.trim().isNotEmpty) {
      setState(() {
        _specialties.add(_specialtyController.text.trim());
        _specialtyController.clear();
      });
    }
  }

  Future<void> _pickImage(String path, Function(String) onUpload) async {
    final chefProvider = Provider.of<ChefProvider>(context, listen: false);
    final url = await chefProvider.pickAndUploadImage(path);
    if (url != null) {
      setState(() => onUpload(url));
    }
  }

  void _submitSetup() async {
    if (_formKey.currentState!.validate()) {
      if (_imageUrl == null) {
        _showError("Please upload a kitchen cover photo");
        return;
      }
      if (_idProofUrl == null || _licenseUrl == null) {
        _showError("Please upload all required KYC documents");
        return;
      }
      if (_specialties.isEmpty) {
        _showError("Please add at least one specialty");
        return;
      }

      setState(() => _isGettingLocation = true);
      
      try {
        final position = await _locationService.getCurrentLocation();
        if (position == null) throw "Could not determine location. Please enable GPS.";

        if (!mounted) return;
        final chefProvider = Provider.of<ChefProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final profile = authProvider.userProfile;
        final uid = profile?['uid'] ?? '';
        final name = profile?['name'] ?? 'Home Chef';

        if (uid.isNotEmpty) {
          final newKitchen = KitchenModel(
            id: '',
            chefId: uid,
            name: _nameController.text.trim(),
            chefName: name,
            address: _addressController.text.trim(),
            rating: 5.0,
            totalRatings: 0,
            imageUrl: _imageUrl!,
            specialties: _specialties,
            categories: [], // Can be filled based on specialties
            isOpen: true,
            status: 'pending',
            latitude: position.latitude,
            longitude: position.longitude,
            fssaiNumber: _fssaiController.text.trim(),
            idProofUrl: _idProofUrl,
            licenseUrl: _licenseUrl,
          );

          await chefProvider.createKitchen(newKitchen.toMap());
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Application submitted! We will verify your documents soon."),
                backgroundColor: AppTheme.secondaryColor,
              ),
            );
          }
        }
      } catch (e) {
        _showError("Error: $e");
      } finally {
        if (mounted) setState(() => _isGettingLocation = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chefProvider = Provider.of<ChefProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Registration"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Kitchen Branding"),
              _buildImagePicker("Cover Photo", _imageUrl, (url) => _imageUrl = url, chefProvider.isLoading),
              const SizedBox(height: 32),
              _buildSectionTitle("Basic Information"),
              _buildTextField(_nameController, "Kitchen Name", "e.g. Mom's Kitchen"),
              const SizedBox(height: 20),
              _buildTextField(_addressController, "Full Address", "Where is the food prepared?", maxLines: 3),
              const SizedBox(height: 32),
              _buildSpecialtiesSection(),
              const SizedBox(height: 32),
              _buildSectionTitle("Verification & KYC"),
              _buildTextField(_fssaiController, "FSSAI License Number", "12-digit number"),
              const SizedBox(height: 20),
              _buildDocPicker("Govt. ID Proof (Aadhar/PAN)", _idProofUrl, (url) => _idProofUrl = url, chefProvider.isLoading),
              const SizedBox(height: 16),
              _buildDocPicker("Food Safety License (FSSAI)", _licenseUrl, (url) => _licenseUrl = url, chefProvider.isLoading),
              const SizedBox(height: 48),
              _buildSubmitButton(chefProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildImagePicker(String label, String? url, Function(String) onUpload, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : () => _pickImage(AppConstants.kitchenImagesPath, onUpload),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
        ),
        child: url == null 
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                Text(label, style: TextStyle(color: Colors.grey[600])),
              ])
            : null,
      ),
    );
  }

  Widget _buildDocPicker(String label, String? url, Function(String) onUpload, bool isLoading) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(url != null ? Icons.check_circle : Icons.upload_file, color: url != null ? Colors.green : Colors.grey),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: isLoading && url == null ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add, size: 20),
      onTap: isLoading ? null : () => _pickImage('kyc_docs', onUpload),
    );
  }

  Widget _buildSpecialtiesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Cuisine Specialties", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: _specialtyController, decoration: const InputDecoration(hintText: "e.g. Punjabi, Vegan"))),
        IconButton(onPressed: _addSpecialty, icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor)),
      ]),
      Wrap(spacing: 8, children: _specialties.map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _specialties.remove(s)))).toList()),
    ]);
  }

  Widget _buildSubmitButton(ChefProvider chefProvider) {
    return (chefProvider.isLoading || _isGettingLocation)
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton(
            onPressed: _submitSetup,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, minimumSize: const Size(double.infinity, 50)),
            child: const Text("Launch Kitchen"),
          );
  }
}
