import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/domain/models/business_hours_model.dart';
import '../../../customer/domain/models/kitchen_model.dart';
import '../providers/chef_provider.dart';

class ManageHoursScreen extends StatefulWidget {
  final KitchenModel kitchen;
  const ManageHoursScreen({super.key, required this.kitchen});

  @override
  State<ManageHoursScreen> createState() => _ManageHoursScreenState();
}

class _ManageHoursScreenState extends State<ManageHoursScreen> {
  late Map<String, BusinessHoursModel> _tempHours;
  bool _isSaving = false;

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with existing hours or defaults
    _tempHours = Map.from(widget.kitchen.businessHours);
    for (var day in _days) {
      _tempHours.putIfAbsent(
        day,
        () => BusinessHoursModel(
          openTime: const TimeOfDay(hour: 9, minute: 0),
          closeTime: const TimeOfDay(hour: 21, minute: 0),
        ),
      );
    }
  }

  Future<void> _selectTime(BuildContext context, String day, bool isOpenTime) async {
    final current = isOpenTime ? _tempHours[day]!.openTime : _tempHours[day]!.closeTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (picked != null && picked != current) {
      setState(() {
        _tempHours[day] = BusinessHoursModel(
          openTime: isOpenTime ? picked : _tempHours[day]!.openTime,
          closeTime: isOpenTime ? _tempHours[day]!.closeTime : picked,
          isClosed: _tempHours[day]!.isClosed,
        );
      });
    }
  }

  void _save() async {
    setState(() => _isSaving = true);
    final provider = context.read<ChefProvider>();
    
    final updatedKitchen = KitchenModel(
      id: widget.kitchen.id,
      chefId: widget.kitchen.chefId,
      name: widget.kitchen.name,
      chefName: widget.kitchen.chefName,
      address: widget.kitchen.address,
      rating: widget.kitchen.rating,
      totalRatings: widget.kitchen.totalRatings,
      imageUrl: widget.kitchen.imageUrl,
      galleryImages: widget.kitchen.galleryImages,
      specialties: widget.kitchen.specialties,
      categories: widget.kitchen.categories,
      isOpen: widget.kitchen.isOpen,
      status: widget.kitchen.status,
      latitude: widget.kitchen.latitude,
      longitude: widget.kitchen.longitude,
      fssaiNumber: widget.kitchen.fssaiNumber,
      idProofUrl: widget.kitchen.idProofUrl,
      licenseUrl: widget.kitchen.licenseUrl,
      businessHours: _tempHours,
    );

    try {
      await provider.updateKitchenDetails(updatedKitchen.toMap());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Business hours updated!"), backgroundColor: AppTheme.secondaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Business Hours"),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: const Text("SAVE", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _days.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final day = _days[index];
          final hours = _tempHours[day]!;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text(hours.isClosed ? "Closed" : "Open", style: TextStyle(color: hours.isClosed ? Colors.red : Colors.green, fontSize: 12)),
                        Switch(
                          value: !hours.isClosed,
                          activeThumbColor: AppTheme.secondaryColor,
                          onChanged: (val) {
                            setState(() {
                              _tempHours[day] = BusinessHoursModel(
                                openTime: hours.openTime,
                                closeTime: hours.closeTime,
                                isClosed: !val,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (!hours.isClosed)
                  Row(
                    children: [
                      _timeTile("Opens at", hours.openTime, () => _selectTime(context, day, true)),
                      const SizedBox(width: 20),
                      _timeTile("Closes at", hours.closeTime, () => _selectTime(context, day, false)),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
