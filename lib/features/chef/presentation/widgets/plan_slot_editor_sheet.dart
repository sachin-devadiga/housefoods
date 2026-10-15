import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_cached_image.dart';
import '../../domain/models/meal_plan_model.dart';
import '../providers/chef_provider.dart';

/// Bottom sheet for editing one cell of the weekly template: its title, the
/// dishes it cooks, and whether it is active.
///
/// Items are snapshotted from the kitchen's existing MenuItems via
/// [ChefProvider.myDishes] (already fetched by `ChefProvider.fetchDishes`).
class PlanSlotEditorSheet extends StatefulWidget {
  final MealPlanSlot slot;
  final String dayName;

  /// Receives the edited slot, or null when the chef clears the cell.
  final ValueChanged<MealPlanSlot?> onDone;

  const PlanSlotEditorSheet({
    super.key,
    required this.slot,
    required this.dayName,
    required this.onDone,
  });

  @override
  State<PlanSlotEditorSheet> createState() => _PlanSlotEditorSheetState();
}

class _PlanSlotEditorSheetState extends State<PlanSlotEditorSheet> {
  late final TextEditingController _titleController;
  late List<MealPlanItem> _items;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.slot.title);
    _items = List.of(widget.slot.items);
    _isActive = widget.slot.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  double get _slotTotal {
    var total = 0.0;
    for (final item in _items) {
      total += item.lineTotal;
    }
    return total;
  }

  void _addDish(Map<String, dynamic> dish) {
    final id = dish['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _items = [
        ..._items,
        MealPlanItem(
          menuItemId: id,
          name: dish['name']?.toString() ?? '',
          // Snapshot the price as a string — Decimal end to end on the backend.
          price: (dish['price'] ?? 0).toString(),
          qty: 1,
        ),
      ];
    });
  }

  void _changeQty(int index, int delta) {
    setState(() {
      final next = _items[index].qty + delta;
      if (next <= 0) {
        _items = List.of(_items)..removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(qty: next);
      }
    });
  }

  void _openDishPicker() {
    final dishes = context.read<ChefProvider>().myDishes;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (dishes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('Your menu is empty.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Add dishes from the Menu tab first.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return SizedBox(
          height: 400,
          child: Consumer<ChefProvider>(
            builder: (context, provider, child) => ListView.builder(
              itemCount: dishes.length,
              itemBuilder: (context, index) {
                final dish = dishes[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: AppCachedImage(
                    imageUrl: dish['imageUrl'] ?? '',
                    height: 44,
                    width: 44,
                    borderRadius: 8,
                  ),
                  title: Text(dish['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('₹${(dish['price'] ?? 0).toString()}'),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppTheme.secondaryColor),
                  onTap: () {
                    _addDish(dish);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _save() {
    widget.onDone(widget.slot.copyWith(
      title: _titleController.text.trim(),
      items: _items,
      isActive: _isActive,
    ));
    Navigator.pop(context);
  }

  void _clear() {
    widget.onDone(null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.dayName} · ${_mealTypeLabel(widget.slot.mealType)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Slot title',
              hintText: 'e.g. Dal Rice',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dishes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Switch(
                value: _isActive,
                activeThumbColor: AppTheme.secondaryColor,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
          Text(_isActive ? 'This slot will be cooked' : 'Paused — not cooked',
              style: TextStyle(
                  fontSize: 12,
                  color: _isActive ? AppTheme.secondaryColor : Colors.grey)),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text('No dishes yet. Add at least one.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text('₹${item.price} each'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => _changeQty(index, -1),
                        ),
                        Text('${item.qty}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => _changeQty(index, 1),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.secondaryColor),
              onPressed: _openDishPicker,
              icon: const Icon(Icons.add),
              label: const Text('Add dish from menu'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Slot value: ₹${_slotTotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _items.isEmpty ? null : _clear,
                  child: const Text('Clear cell'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor),
                  onPressed: _save,
                  child: const Text('SAVE', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _mealTypeLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      default:
        return 'Dinner';
    }
  }
}