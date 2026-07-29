import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/daily_menu_model.dart';
import '../providers/chef_provider.dart';
import '../widgets/dish_picker_sheet.dart';

class ManageDailyMenuScreen extends StatefulWidget {
  const ManageDailyMenuScreen({super.key});

  @override
  State<ManageDailyMenuScreen> createState() => _ManageDailyMenuScreenState();
}

class _ManageDailyMenuScreenState extends State<ManageDailyMenuScreen> {
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isVeg = true;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadMenuForDate(_selectedDate);
  }

  void _loadMenuForDate(DateTime date) {
    final provider = context.read<ChefProvider>();
    final lookupDate = DateTime(date.year, date.month, date.day);
    final dailyMenusList = provider.myKitchen?['daily_menus'];
    Map<String, dynamic>? existing;
    if (dailyMenusList is List) {
      for (var menu in dailyMenusList) {
        final menuDate = DateTime.tryParse(menu['date']?.toString() ?? '');
        if (menuDate != null &&
            menuDate.year == lookupDate.year &&
            menuDate.month == lookupDate.month &&
            menuDate.day == lookupDate.day) {
          existing = menu;
          break;
        }
      }
    }

    if (existing != null) {
      _titleController.text = existing['mealTitle'] ?? '';
      _descController.text = existing['description'] ?? '';
      _isVeg = existing['isVeg'] ?? true;
      _imageUrl = existing['imageUrl'];
    } else {
      _titleController.clear();
      _descController.clear();
      _isVeg = true;
      _imageUrl = null;
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
            _titleController.text = dish.name;
            _descController.text = dish.description;
            _isVeg = dish.isVeg;
            _imageUrl = dish.imageUrl;
          });
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final provider = context.read<ChefProvider>();
    final url = await provider.pickAndUploadImage(AppConstants.mealImagesPath);
    if (url != null) {
      setState(() => _imageUrl = url);
    }
  }

  void _saveMenu() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<ChefProvider>();
      final menu = DailyMenuModel(
        id: '', 
        kitchenId: provider.myKitchen!['id'],
        date: _selectedDate,
        mealTitle: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: _imageUrl ?? '',
        isVeg: _isVeg,
      );

      try {
        await provider.saveDailyMenu(menu.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Menu saved successfully!"), backgroundColor: AppTheme.secondaryColor),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Calendar"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildCalendarStrip(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showDishPicker,
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text("Pick from Dish Library"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        foregroundColor: AppTheme.secondaryColor,
                        side: const BorderSide(color: AppTheme.secondaryColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    Text(
                      "Meal for ${DateFormat('EEEE, dd MMM').format(_selectedDate)}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Meal Title",
                        hintText: "e.g. Special Paneer Thali",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description / Menu Details",
                        hintText: "List items like Sabzi, Roti, Rice...",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text("Meal Category:"),
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
                    const SizedBox(height: 40),
                    Consumer<ChefProvider>(
                      builder: (context, provider, child) {
                        return provider.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _saveMenu,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                                child: const Text("Save Daily Special"),
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadMenuForDate(date);
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.secondaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12),
                  ),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          image: _imageUrl != null ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover) : null,
        ),
        child: _imageUrl == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  Text("Add Meal Photo", style: TextStyle(color: Colors.grey)),
                ],
              )
            : null,
      ),
    );
  }
}
