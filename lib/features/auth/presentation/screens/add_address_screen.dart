import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/address_model.dart';
import '../../domain/models/user_model.dart';
import 'map_picker_screen.dart';

class AddAddressScreen extends StatefulWidget {
  final UserModel user;
  const AddAddressScreen({super.key, required this.user});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  String _selectedLabel = 'Home';
  bool _isLoading = false;

  void _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _addressController.text = result['address'] ?? '';
        // In a real scenario, you might parse the 'name' of the place into the house controller
      });
    }
  }

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final newAddress = AddressModel(
          id: const Uuid().v4(),
          label: _selectedLabel,
          fullAddress: _addressController.text.trim(),
          houseNo: _houseController.text.trim(),
          landmark: _landmarkController.text.trim(),
        );

        final updatedAddresses = List<AddressModel>.from(widget.user.addresses)..add(newAddress);
        
        await UserRepositoryImpl().updateAddresses(widget.user.uid, updatedAddresses);

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Address")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Entry Point
              _buildMapShortcut(),
              const SizedBox(height: 32),
              
              const Text("Save address as", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: ['Home', 'Work', 'Other'].map((label) {
                  bool isSelected = _selectedLabel == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedLabel = label),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _houseController,
                decoration: InputDecoration(
                  labelText: "House / Flat / Block No.",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Full Address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                    onPressed: _openMapPicker,
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _landmarkController,
                decoration: InputDecoration(
                  labelText: "Landmark (Optional)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveAddress,
                      child: const Text("Save Address"),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapShortcut() {
    return InkWell(
      onTap: _openMapPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.map_outlined, color: AppTheme.primaryColor),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Select Location via Map", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("For better delivery accuracy", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
