import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Platform Users"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allUsers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.allUsers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final user = provider.allUsers[index];
              return ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: CircleAvatar(
                  backgroundColor: (user['role'] ?? '') == 'chef'
                      ? AppTheme.secondaryColor
                      : (user['role'] ?? '') == 'delivery_partner' ? Colors.orange : AppTheme.primaryColor,
                  child: Icon(
                    (user['role'] ?? '') == 'chef'
                        ? Icons.restaurant
                        : (user['role'] ?? '') == 'delivery_partner' ? Icons.delivery_dining : Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['phone'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      "Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(user['created_at'].toString()))}",
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ((user['role'] ?? '') == 'chef'
                            ? Colors.green
                            : (user['role'] ?? '') == 'delivery_partner' ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (user['role'] ?? '').toString().toUpperCase(),
                    style: TextStyle(
                      color: (user['role'] ?? '') == 'chef'
                          ? Colors.green
                          : (user['role'] ?? '') == 'delivery_partner' ? Colors.orange : Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
