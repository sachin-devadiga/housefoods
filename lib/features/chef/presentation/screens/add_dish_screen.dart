import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/dish_model.dart';
import '../providers/chef_provider.dart';

class AddDishScreen extends StatefulWidget {
  const AddDishScreen({super.key});

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isVeg = true;
  String? _imageUrl;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final provider = context.read<ChefProvider>();
    try {
      final url = await provider.pickAndUploadImage('dishes');
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        setState(() {
          _imageUrl = url;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo upload failed. Please try again.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Photo upload failed: $e")),
      );
    }
  }

  void _saveDish() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ChefProvider>();
    final kitchen = provider.myKitchen;
    if (kitchen == null || kitchen['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kitchen not loaded. Please go back and reopen this screen.")),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid price")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dish = DishModel(
        id: '',
        kitchenId: kitchen['id'].toString(),
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrl ?? '',
        isVeg: _isVeg,
        price: price,
      );

      await provider.addDish(dish.toMap());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dish added to library!"), backgroundColor: AppTheme.secondaryColor),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not save dish: $e"), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ChefProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Dish"),
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
              _buildImagePicker(isLoading),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Dish Name",
                  hintText: "e.g. Butter Paneer Masala",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Briefly describe the dish and its ingredients...",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Price (₹)",
                  hintText: "e.g. 149",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  final price = double.tryParse(v);
                  if (price == null || price <= 0) return "Enter a valid price";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text("Category:"),
                  const SizedBox(width: 20),
                  ChoiceChip(
                    label: const Text("Veg"),
                    selected: _isVeg,
                    onSelected: (s) => setState(() => _isVeg = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Non-Veg"),
                    selected: !_isVeg,
                    onSelected: (s) => setState(() => _isVeg = false),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSaving || isLoading) ? null : _saveDish,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text("Save to Library", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          image: _imageUrl != null ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover) : null,
        ),
        child: _imageUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    )
                  else
                    const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    isLoading ? "Uploading..." : "Upload Dish Photo (optional)",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
