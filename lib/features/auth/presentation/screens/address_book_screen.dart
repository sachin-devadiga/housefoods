import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/address_model.dart';
import '../providers/auth_provider.dart';
import 'add_address_screen.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isNotEmpty) {
      try {
        final userData = await UserRepositoryImpl().getUser(uid);
        setState(() {
          _user = userData;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load addresses"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    if (_user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Address"),
        content: const Text("Are you sure you want to remove this address?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = _user!.addresses.where((a) => a.id != address.id).toList();
    try {
      await UserRepositoryImpl().updateAddresses(_user!.uid, updated);
      _loadUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address removed")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to remove address"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Addresses")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null || _user!.addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_user != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddAddressScreen(user: _user!)),
            ).then((result) {
              _loadUserData();
              if (!context.mounted) return;
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Address saved successfully"), backgroundColor: Colors.green),
                );
              }
            });
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add New", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No addresses saved yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _user!.addresses.length,
      itemBuilder: (context, index) {
        final address = _user!.addresses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              address.label == 'Home' ? Icons.home : address.label == 'Work' ? Icons.work : Icons.location_on,
              color: AppTheme.primaryColor,
            ),
            title: Text(address.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("${address.houseNo}, ${address.fullAddress}"),
                if (address.landmark.isNotEmpty) Text("Landmark: ${address.landmark}", style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteAddress(address),
            ),
          ),
        );
      },
    );
  }
}
