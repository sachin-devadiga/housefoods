import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _selectedRole = '';
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _roles = [
    {'label': 'All', 'value': ''},
    {'label': 'Customers', 'value': 'customer'},
    {'label': 'Chefs', 'value': 'chef'},
    {'label': 'Riders', 'value': 'delivery_partner'},
    {'label': 'Admins', 'value': 'admin'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAllUsers();
    });
  }

  void _filterUsers() {
    context.read<AdminProvider>().fetchAllUsers(
          role: _selectedRole.isNotEmpty ? _selectedRole : null,
          search: _searchController.text.isNotEmpty ? _searchController.text : null,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _filterUsers(),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isSelected = _selectedRole == role['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(role['label']),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedRole = role['value']);
                      _filterUsers();
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<AdminProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.allUsers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.allUsers.isEmpty) {
                  return const Center(child: Text('No users found', style: TextStyle(color: Colors.grey)));
                }
                return RefreshIndicator(
                  onRefresh: () => provider.fetchAllUsers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.allUsers.length,
                    itemBuilder: (context, index) {
                      final user = provider.allUsers[index];
                      final isActive = user['is_active'] ?? true;
                      final role = user['role'] ?? 'unknown';
                      final name = user['name'] ?? '';
                      final email = user['email'] ?? '';
                      final avatarUrl = user['avatar_url'] ?? '';

                      Color roleColor;
                      switch (role) {
                        case 'admin':
                          roleColor = Colors.red;
                          break;
                        case 'chef':
                          roleColor = Colors.orange;
                          break;
                        case 'delivery_partner':
                          roleColor = Colors.green;
                          break;
                        default:
                          roleColor = Colors.blue;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: roleColor.withValues(alpha: 0.15),
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)) : null,
                          ),
                          title: Text(name.isNotEmpty ? name : email, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(role.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: isActive,
                                onChanged: (val) => _toggleUser(provider, user['uid'], val),
                                activeThumbColor: Colors.green,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleUser(AdminProvider provider, String uid, bool isActive) async {
    await provider.toggleUserActive(uid, isActive);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'User activated' : 'User deactivated'),
          backgroundColor: isActive ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
