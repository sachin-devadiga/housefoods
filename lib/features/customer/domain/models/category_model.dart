import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
  });
}

final List<CategoryModel> appCategories = [
  CategoryModel(id: 'all', name: 'All', icon: Icons.restaurant_menu),
  CategoryModel(id: 'thali', name: 'Thali', icon: Icons.flatware),
  CategoryModel(id: 'healthy', name: 'Healthy', icon: Icons.health_and_safety),
  CategoryModel(id: 'homestyle', name: 'Home-style', icon: Icons.home),
  CategoryModel(id: 'breakfast', name: 'Breakfast', icon: Icons.breakfast_dining),
  CategoryModel(id: 'snacks', name: 'Snacks', icon: Icons.fastfood),
  CategoryModel(id: 'dessert', name: 'Desserts', icon: Icons.icecream),
];
