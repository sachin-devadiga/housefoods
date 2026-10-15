import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/meal_plan_model.dart';
import '../providers/meal_plan_provider.dart';
import '../widgets/plan_slot_editor_sheet.dart';
import 'plan_pricing_screen.dart';

/// The 7 days × 3 meal types weekly template.
///
/// Rows are days (0 = Monday), columns are breakfast/lunch/dinner. A cell shows
/// either nothing or a summary ("Dal Rice ×2") plus the slot's value. Editing
/// state lives in [MealPlanProvider] so the pricing screen and back-navigation
/// do not lose the grid.
class WeeklyPlanBuilderScreen extends StatefulWidget {
  final MealPlan? plan;

  const WeeklyPlanBuilderScreen({super.key, this.plan});

  @override
  State<WeeklyPlanBuilderScreen> createState() => _WeeklyPlanBuilderScreenState();
}

class _WeeklyPlanBuilderScreenState extends State<WeeklyPlanBuilderScreen> {
  static const List<String> _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _mealTypes = ['breakfast', 'lunch', 'dinner'];
  static const Map<String, String> _mealLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
  };

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MealPlanProvider>().startDraft(widget.plan);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openCell(int dayOfWeek, String mealType) {
    final provider = context.read<MealPlanProvider>();
    final existing = provider.slotAt(dayOfWeek, mealType);
    final slot = existing ??
        MealPlanSlot(
          dayOfWeek: dayOfWeek,
          dayName: _dayNames[dayOfWeek],
          mealType: mealType,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PlanSlotEditorSheet(
        slot: slot,
        dayName: _dayNames[dayOfWeek],
        onDone: (updated) {
          if (!mounted) return;
          if (updated == null) {
            provider.upsertSlot(slot.copyWith(items: const [], title: ''));
          } else {
            provider.upsertSlot(updated);
          }
        },
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<MealPlanProvider>();
    final name = provider.draft?.name ?? '';
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the plan a name first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    await provider.savePlan(provider.buildDraftPlan());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Kept in this session — publishing plans is not available yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MealPlanProvider>(
      builder: (context, provider, child) {
        final plan = provider.buildDraftPlan();
        final filledCells =
            provider.draftSlots.values.where((s) => !s.isEmpty).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Weekly Plan'),
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.sell_outlined),
                tooltip: 'Pricing',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanPricingScreen(plan: plan),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('planNameField'),
                controller: _nameController,
                onChanged: provider.setDraftName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Plan name',
                  hintText: 'e.g. 7-Day Home Meals',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.grid_view, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '$filledCells of 21 cells filled',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    'Weekly value ₹${plan.weeklySlotTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var day = 0; day < _dayNames.length; day++)
                _buildDayRow(day, provider),
              const SizedBox(height: 24),
              if (!provider.canPersistPlans)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Plan publishing is not wired to the server yet. Your grid is '
                    'kept for this session only.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: provider.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('SAVE PLAN',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayRow(int day, MealPlanProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _dayNames[day],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          for (final mealType in _mealTypes)
            Expanded(
              child: _buildCell(
                MealPlanSlot(
                  dayOfWeek: day,
                  dayName: _dayNames[day],
                  mealType: mealType,
                ),
                provider,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(MealPlanSlot key, MealPlanProvider provider) {
    final slot = provider.slotAt(key.dayOfWeek, key.mealType) ?? key;
    final hasItems = !slot.isEmpty;
    final inactive = !slot.isActive;
    final borderColor = !hasItems
        ? Colors.grey.shade300
        : inactive
            ? Colors.grey
            : AppTheme.secondaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openCell(key.dayOfWeek, key.mealType),
        onLongPress: hasItems
            ? () => provider.setSlotActive(key.dayOfWeek, key.mealType, inactive)
            : null,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasItems && !inactive
                ? AppTheme.secondaryColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: hasItems ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _mealLabels[key.mealType]!.substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasItems && !inactive
                          ? AppTheme.secondaryColor
                          : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (hasItems)
                    Icon(
                      inactive
                          ? Icons.pause_circle_outline
                          : Icons.check_circle,
                      size: 13,
                      color: inactive ? Colors.grey : AppTheme.secondaryColor,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  hasItems ? slot.summary : '+',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasItems ? FontWeight.w600 : FontWeight.normal,
                    color: hasItems ? Colors.black87 : Colors.grey.shade400,
                  ),
                ),
              ),
              if (hasItems)
                Text(
                  '₹${slot.slotTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: inactive ? Colors.grey : AppTheme.secondaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}