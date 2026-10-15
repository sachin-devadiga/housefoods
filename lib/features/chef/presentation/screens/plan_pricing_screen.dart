import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/meal_plan_model.dart';
import '../providers/meal_plan_provider.dart';

/// Week / month / year pricing for a plan.
///
/// `duration_days` is never sent: the backend derives it from the cadence
/// (`PlanPrice.DURATION_DAYS` = 7 / 30 / 365). The hint below mirrors those
/// numbers so the chef can price consistently.
class PlanPricingScreen extends StatefulWidget {
  final MealPlan plan;

  const PlanPricingScreen({super.key, required this.plan});

  @override
  State<PlanPricingScreen> createState() => _PlanPricingScreenState();
}

class _PlanPricingScreenState extends State<PlanPricingScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _active = {};

  @override
  void initState() {
    super.initState();
    for (final cadence in PlanPrice.cadences) {
      final existing = widget.plan.priceFor(cadence);
      _controllers[cadence] = TextEditingController(
        text: existing == null ? '' : existing.price,
      );
      _active[cadence] = existing?.isActive ?? true;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _update(String cadence, String value) {
    final provider = context.read<MealPlanProvider>();
    final text = value.trim();
    if (text.isEmpty) {
      provider.upsertPrice(PlanPrice(
        cadence: cadence,
        price: '',
        isActive: _active[cadence] ?? true,
      ));
      return;
    }
    provider.upsertPrice(PlanPrice(
      cadence: cadence,
      price: text,
      isActive: _active[cadence] ?? true,
    ));
  }

  void _setActive(String cadence, bool value) {
    setState(() => _active[cadence] = value);
    final controller = _controllers[cadence];
    context.read<MealPlanProvider>().upsertPrice(PlanPrice(
          cadence: cadence,
          price: controller?.text.trim() ?? '',
          isActive: value,
        ));
  }

  Future<void> _save() async {
    final provider = context.read<MealPlanProvider>();
    await provider.savePlan(provider.buildDraftPlan());
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kept in this session — publishing is not available yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MealPlanProvider>();
    final plan = provider.buildDraftPlan();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          plan.name.isEmpty ? 'Pricing' : plan.name,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Cadence maps to a fixed billing period: week = 7 days, '
            'month = 30 days, year = 365 days.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          for (final cadence in PlanPrice.cadences)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPriceRow(cadence, plan),
            ),
          const SizedBox(height: 8),
          if (plan.prices.isEmpty)
            const Text(
              'No prices set. A plan with no active price is never purchasable.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: provider.isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('SAVE PRICING',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String cadence, MealPlan plan) {
    final days = PlanPrice.cadenceDays[cadence] ?? 30;
    final existing = plan.priceFor(cadence);
    final price = double.tryParse(existing?.price ?? '') ?? 0;
    final perMeal = plan.activeSlotCount == 0
        ? 0.0
        : price / (plan.activeSlotCount * days / 7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cadence[0].toUpperCase()}${cadence.substring(1)}ly',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text('$days days', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (perMeal > 0)
                  Text(
                    '≈ ₹${perMeal.toStringAsFixed(0)} per meal',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: _controllers[cadence],
              onChanged: (v) => _update(cadence, v),
              decoration: const InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
          Switch(
            value: _active[cadence] ?? true,
            activeThumbColor: AppTheme.secondaryColor,
            onChanged: (v) => _setActive(cadence, v),
          ),
        ],
      ),
    );
  }
}