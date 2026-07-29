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
  bool _isVeg = true;
  String? _imageUrl;

  Future<void> _pickImage() async {
    final provider = context.read<ChefProvider>();
    final url = await provider.pickAndUploadImage('dishes');
    if (url != null) {
      setState(() => _imageUrl = url);
    }
  }

  void _saveDish() async {
    if (_formKey.currentState!.validate()) {
      if (_imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload a photo of the dish")),
        );
        return;
      }

      final provider = context.read<ChefProvider>();
      final dish = DishModel(
        id: '',
        kitchenId: provider.myKitchen!['id'],
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrl!,
        isVeg: _isVeg,
      );

      try {
        await provider.addDish(dish.toMap());
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Dish added to library!"), backgroundColor: AppTheme.secondaryColor),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
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
              isLoading && _imageUrl == null
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveDish,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                      child: const Text("Save to Library"),
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
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                  Text("Upload Dish Photo", style: TextStyle(color: Colors.grey)),
                ],
              )
            : null,
      ),
    );
  }
}
