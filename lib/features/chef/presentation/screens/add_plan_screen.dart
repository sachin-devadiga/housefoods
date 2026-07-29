import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/customer/domain/models/subscription_plan_model.dart';
import '../providers/chef_provider.dart';
import '../widgets/dish_picker_sheet.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _inclusionController = TextEditingController();

  final List<String> _inclusions = [];
  bool _isVeg = true;
  String? _imageUrl;

  void _addInclusion() {
    if (_inclusionController.text.trim().isNotEmpty) {
      setState(() {
        _inclusions.add(_inclusionController.text.trim());
        _inclusionController.clear();
      });
    }
  }

  void _showDishPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DishPickerSheet(
        onDishSelected: (dish) {
          setState(() {
            _nameController.text = dish.name;
            _descController.text = dish.description;
            _isVeg = dish.isVeg;
            _imageUrl = dish.imageUrl;
          });
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final chefProvider = Provider.of<ChefProvider>(context, listen: false);
    final url = await chefProvider.pickAndUploadImage(AppConstants.mealImagesPath);
    if (url != null) {
      setState(() {
        _imageUrl = url;
      });
    }
  }

  void _savePlan() async {
    if (_formKey.currentState!.validate()) {
      if (_imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload a photo of the meal")),
        );
        return;
      }
      if (_inclusions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least one inclusion")),
        );
        return;
      }

      final chefProvider = Provider.of<ChefProvider>(context, listen: false);
      
      final newPlan = SubscriptionPlanModel(
        id: '', 
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        durationDays: int.parse(_durationController.text.trim()),
        inclusions: _inclusions,
        isVeg: _isVeg,
        imageUrl: _imageUrl!,
      );

      await chefProvider.addPlan(newPlan.toMap());
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Plan added successfully"), backgroundColor: AppTheme.secondaryColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chefProvider = Provider.of<ChefProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Subscription Plan"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _showDishPicker,
                icon: const Icon(Icons.library_books_outlined),
                label: const Text("Import from Dish Library"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: AppTheme.secondaryColor,
                  side: const BorderSide(color: AppTheme.secondaryColor),
                ),
              ),
              const SizedBox(height: 24),
              _buildImagePicker(chefProvider.isLoading),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Plan Name",
                  hintText: "e.g. Weekly Executive Thali",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Price (₹)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Duration (Days)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text("Category:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  ChoiceChip(
                    label: const Text("Veg"),
                    selected: _isVeg,
                    onSelected: (val) => setState(() => _isVeg = true),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Non-Veg"),
                    selected: !_isVeg,
                    onSelected: (val) => setState(() => _isVeg = false),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text("Inclusions (What's in the meal?)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inclusionController,
                      decoration: const InputDecoration(hintText: "e.g. 4 Rotis, 2 Sabzi"),
                    ),
                  ),
                  IconButton(
                    onPressed: _addInclusion,
                    icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _inclusions.map((item) => Chip(
                  label: Text(item, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => setState(() => _inclusions.remove(item)),
                )).toList(),
              ),
              const SizedBox(height: 40),
              chefProvider.isLoading && _imageUrl == null
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _savePlan,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                      child: const Text("Save Plan"),
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
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          image: _imageUrl != null
              ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: _imageUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood_outlined, size: 50, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text("Upload Meal Photo", style: TextStyle(color: Colors.grey[600])),
                  if (isLoading) const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 20, color: AppTheme.secondaryColor),
                ),
              ),
      ),
    );
  }
}
