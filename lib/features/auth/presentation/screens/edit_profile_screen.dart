import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../chef/presentation/providers/chef_provider.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final ApiService? apiService;
  const EditProfileScreen({super.key, required this.user, this.apiService});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _profileImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _profileImageUrl = widget.user.profileImage;
  }

  Future<void> _updatePhoto() async {
    final chefProvider = Provider.of<ChefProvider>(context, listen: false);
    try {
      final url = await chefProvider.pickAndUploadImage(AppConstants.profileImagesPath);
      if (url != null && url.isNotEmpty) {
        setState(() {
          _profileImageUrl = url;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload photo"), backgroundColor: AppTheme.errorColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final updatedUser = UserModel(
          uid: widget.user.uid,
          email: widget.user.email,
          phoneNumber: widget.user.phoneNumber,
          name: _nameController.text.trim(),
          role: widget.user.role,
          profileImage: _profileImageUrl,
          createdAt: widget.user.createdAt,
          addresses: widget.user.addresses,
          referralCode: widget.user.referralCode,
        );

        await UserRepositoryImpl(apiService: widget.apiService).updateUser(updatedUser);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully"), backgroundColor: AppTheme.secondaryColor),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                    child: _profileImageUrl == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _updatePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: widget.user.email.isNotEmpty ? widget.user.email : widget.user.phoneNumber,
                enabled: false,
                decoration: InputDecoration(
                  labelText: widget.user.email.isNotEmpty ? "Email" : "Phone Number",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 40),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text("Save Changes"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
