import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/user_model.dart';

class DietarySetupScreen extends StatefulWidget {
  final UserModel user;
  const DietarySetupScreen({super.key, required this.user});

  @override
  State<DietarySetupScreen> createState() => _DietarySetupScreenState();
}

class _DietarySetupScreenState extends State<DietarySetupScreen> {
  String _selectedDiet = 'none';
  final List<String> _allergies = [];
  final TextEditingController _allergyController = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _dietOptions = [
    {'id': 'none', 'name': 'Anything', 'icon': Icons.all_inclusive},
    {'id': 'veg', 'name': 'Vegetarian', 'icon': Icons.eco},
    {'id': 'vegan', 'name': 'Vegan', 'icon': Icons.grass},
    {'id': 'keto', 'name': 'Keto', 'icon': Icons.fitness_center},
    {'id': 'paleo', 'name': 'Paleo', 'icon': Icons.set_meal},
  ];

  void _addAllergy() {
    final text = _allergyController.text.trim();
    if (text.isNotEmpty && !_allergies.contains(text)) {
      setState(() {
        _allergies.add(text);
        _allergyController.clear();
      });
    }
  }

  void _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      final updatedUser = UserModel(
        uid: widget.user.uid,
        phoneNumber: widget.user.phoneNumber,
        name: widget.user.name,
        role: widget.user.role,
        profileImage: widget.user.profileImage,
        createdAt: widget.user.createdAt,
        addresses: widget.user.addresses,
        favoriteKitchenIds: widget.user.favoriteKitchenIds,
        referralCode: widget.user.referralCode,
        referredBy: widget.user.referredBy,
        walletBalance: widget.user.walletBalance,
        dietaryPreference: _selectedDiet,
        allergies: _allergies,
      );

      await UserRepositoryImpl().updateUser(updatedUser);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dietary preferences saved!"),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Food Preferences")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Help our chefs cook for you",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Tell us your diet and any allergies for a safer meal experience.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            const Text("Primary Diet", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDietGrid(),
            const SizedBox(height: 32),
            const Text("Allergies", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAllergyInput(),
            const SizedBox(height: 12),
            _buildAllergyChips(),
            const SizedBox(height: 48),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _savePreferences,
                    child: const Text("Save Preferences"),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _dietOptions.length,
      itemBuilder: (context, index) {
        final diet = _dietOptions[index];
        bool isSelected = _selectedDiet == diet['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedDiet = diet['id']),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[200]!),
              boxShadow: [
                if (isSelected) BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8)
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(diet['icon'], color: isSelected ? Colors.white : Colors.grey[700]),
                const SizedBox(height: 8),
                Text(
                  diet['name'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllergyInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _allergyController,
            decoration: InputDecoration(
              hintText: "e.g. Peanuts, Shellfish",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _addAllergy,
          icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor, size: 32),
        ),
      ],
    );
  }

  Widget _buildAllergyChips() {
    return Wrap(
      spacing: 8,
      children: _allergies.map((allergy) => Chip(
        label: Text(allergy, style: const TextStyle(fontSize: 12)),
        onDeleted: () => setState(() => _allergies.remove(allergy)),
        backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
        deleteIconColor: AppTheme.errorColor,
        side: BorderSide.none,
      )).toList(),
    );
  }
}
