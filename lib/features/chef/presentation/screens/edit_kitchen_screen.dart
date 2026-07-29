import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../../../features/customer/domain/models/kitchen_model.dart';
import '../providers/chef_provider.dart';

class EditKitchenScreen extends StatefulWidget {
  final KitchenModel kitchen;
  const EditKitchenScreen({super.key, required this.kitchen});

  @override
  State<EditKitchenScreen> createState() => _EditKitchenScreenState();
}

class _EditKitchenScreenState extends State<EditKitchenScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  final TextEditingController _specialtyController = TextEditingController();
  late List<String> _specialties;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.kitchen.name);
    _addressController = TextEditingController(text: widget.kitchen.address);
    _specialties = List.from(widget.kitchen.specialties);
    _imageUrl = widget.kitchen.imageUrl;
  }

  void _addSpecialty() {
    if (_specialtyController.text.trim().isNotEmpty) {
      setState(() {
        _specialties.add(_specialtyController.text.trim());
        _specialtyController.clear();
      });
    }
  }

  Future<void> _updatePhoto() async {
    final provider = Provider.of<ChefProvider>(context, listen: false);
    final url = await provider.pickAndUploadImage(AppConstants.kitchenImagesPath);
    if (url != null) {
      setState(() => _imageUrl = url);
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_specialties.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add at least one specialty")),
        );
        return;
      }

      final provider = Provider.of<ChefProvider>(context, listen: false);
      
      final updated = KitchenModel(
        id: widget.kitchen.id,
        chefId: widget.kitchen.chefId,
        name: _nameController.text.trim(),
        chefName: widget.kitchen.chefName,
        address: _addressController.text.trim(),
        rating: widget.kitchen.rating,
        totalRatings: widget.kitchen.totalRatings,
        imageUrl: _imageUrl ?? widget.kitchen.imageUrl,
        galleryImages: widget.kitchen.galleryImages, // Kept separate for granular updates
        specialties: _specialties,
        categories: widget.kitchen.categories,
        isOpen: widget.kitchen.isOpen,
        status: widget.kitchen.status,
        latitude: widget.kitchen.latitude,
        longitude: widget.kitchen.longitude,
      );

      try {
        await provider.updateKitchenDetails(updated.toMap());
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kitchen details updated!"), backgroundColor: AppTheme.secondaryColor),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChefProvider>(
      builder: (context, provider, child) {
        final kitchen = provider.myKitchen != null
            ? KitchenModel.fromMap(
                provider.myKitchen!,
                (provider.myKitchen!['id'] ?? '').toString(),
              )
            : widget.kitchen;

        return Scaffold(
          appBar: AppBar(title: const Text("Edit Kitchen")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Kitchen Branding"),
                  _buildImageHeader(),
                  const SizedBox(height: 32),
                  
                  _buildSectionTitle("Photo Gallery"),
                  _buildGallerySection(provider, kitchen),
                  const SizedBox(height: 32),

                  _buildSectionTitle("Basic Information"),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Kitchen Name", border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSpecialtiesSection(),
                  const SizedBox(height: 48),
                  
                  provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _saveChanges,
                          child: const Text("Save Kitchen Profile"),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGallerySection(ChefProvider provider, KitchenModel kitchen) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: kitchen.galleryImages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Add Image Button
            return GestureDetector(
              onTap: provider.isLoading ? null : () => provider.addGalleryImage(),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppTheme.secondaryColor),
                    SizedBox(height: 4),
                    Text("Add Photo", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          final imageUrl = kitchen.galleryImages[index - 1];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                AppCachedImage(imageUrl: imageUrl, height: 120, width: 120, borderRadius: 12),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => provider.removeGalleryImage(imageUrl),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialtiesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Specialties", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _specialtyController,
            decoration: const InputDecoration(hintText: "Add specialty"),
          ),
        ),
        IconButton(
          onPressed: _addSpecialty,
          icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor),
        ),
      ]),
      Wrap(
        spacing: 8,
        children: _specialties.map((s) => Chip(
          label: Text(s),
          onDeleted: () => setState(() => _specialties.remove(s)),
        )).toList(),
      ),
    ]);
  }

  Widget _buildImageHeader() {
    return GestureDetector(
      onTap: _updatePhoto,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          image: _imageUrl != null ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover) : null,
        ),
        child: Stack(
          children: [
            if (_imageUrl == null)
              const Center(child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
