import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/kitchen_card.dart';
import 'kitchen_details_screen.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.userProfile?['uid'] ?? '';
      if (uid.isNotEmpty) {
        context.read<FavoritesProvider>().loadFavorites(uid);
      }
      context.read<KitchenProvider>().fetchKitchens();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: Consumer2<FavoritesProvider, KitchenProvider>(
        builder: (context, favProvider, kitchenProvider, child) {
          final favIds = favProvider.favoriteKitchenIds;
          final favKitchens = kitchenProvider.kitchens
              .where((k) => favIds.contains(k.id))
              .toList();

          if (favKitchens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "No favorites yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the heart icon on any kitchen to save it here",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favKitchens.length,
            itemBuilder: (context, index) {
              final kitchen = favKitchens[index];
              return KitchenCard(
                kitchen: kitchen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KitchenDetailsScreen(kitchen: kitchen),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
