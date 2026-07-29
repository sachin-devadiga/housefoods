import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../providers/chef_provider.dart';
import 'add_dish_screen.dart';

class ManageDishesScreen extends StatefulWidget {
  const ManageDishesScreen({super.key});

  @override
  State<ManageDishesScreen> createState() => _ManageDishesScreenState();
}

class _ManageDishesScreenState extends State<ManageDishesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChefProvider>().fetchDishes();
    });
  }

  void _confirmDelete(dynamic dishId, String dishName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Dish?"),
        content: Text("Are you sure you want to remove '$dishName' from your library?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              context.read<ChefProvider>().deleteDish(dishId);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Dish Library"),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ChefProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.myDishes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myDishes.isEmpty) {
            return _buildEmptyState();
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: provider.myDishes.length,
            itemBuilder: (context, index) {
              final dish = provider.myDishes[index];
              return _buildDishCard(dish);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDishScreen()),
        ),
        backgroundColor: AppTheme.secondaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Dish", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "Your library is empty",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your signature dishes here to\nquickly use them in your menus.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(dynamic dish) {
    final dishMap = dish as Map<String, dynamic>;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                AppCachedImage(
                  imageUrl: dishMap['imageUrl'],
                  height: double.infinity,
                  width: double.infinity,
                  borderRadius: 16,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dishMap['isVeg'] == true ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.circle, size: 8, color: Colors.white),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    onPressed: () => _confirmDelete(dishMap['id'], dishMap['name'] ?? ''),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dishMap['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  dishMap['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
