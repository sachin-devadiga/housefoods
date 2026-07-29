import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/dish_model.dart';
import '../providers/chef_provider.dart';

class DishPickerSheet extends StatelessWidget {
  final Function(DishModel) onDishSelected;

  const DishPickerSheet({super.key, required this.onDishSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select from Library",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Consumer<ChefProvider>(
            builder: (context, provider, child) {
              if (provider.myDishes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text("Your library is empty. Save some dishes first.")),
                );
              }

              return SizedBox(
                height: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.myDishes.length,
                  itemBuilder: (context, index) {
                    final dish = provider.myDishes[index];
                    final dishModel = DishModel.fromMap(dish, dish['id']?.toString() ?? '');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: AppCachedImage(
                        imageUrl: dish['imageUrl'] ?? '',
                        height: 50,
                        width: 50,
                        borderRadius: 8,
                      ),
                      title: Text(dish['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        dish['isVeg'] == true ? "Veg" : "Non-Veg",
                        style: TextStyle(color: dish['isVeg'] == true ? Colors.green : Colors.red, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor),
                      onTap: () {
                        onDishSelected(dishModel);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
