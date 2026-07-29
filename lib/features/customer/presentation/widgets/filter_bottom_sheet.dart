import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/kitchen_provider.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<KitchenProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Filters & Sorting",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      provider.setVegFilter(false);
                      provider.setMinRating(0.0);
                      provider.setSortBy('proximity');
                    },
                    child: const Text("Reset All"),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SortChip(
                    label: "Nearest",
                    isSelected: provider.sortBy == 'proximity',
                    onTap: () => provider.setSortBy('proximity'),
                  ),
                  const SizedBox(width: 10),
                  _SortChip(
                    label: "Highest Rated",
                    isSelected: provider.sortBy == 'rating',
                    onTap: () => provider.setSortBy('rating'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text("Dietary Preference", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Pure Veg Only"),
                subtitle: const Text("Show only kitchens serving vegetarian meals"),
                value: provider.isVegOnly,
                activeThumbColor: AppTheme.secondaryColor,
                onChanged: (val) => provider.setVegFilter(val),
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Minimum Rating", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    provider.minRating > 0 ? "${provider.minRating.toStringAsFixed(1)} ★ & up" : "Any",
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: provider.minRating,
                min: 0,
                max: 4.5,
                divisions: 9,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => provider.setMinRating(val),
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Apply Filters"),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
