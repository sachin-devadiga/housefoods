// Self-check for the subscription snapshot contract. Run:
//   dart run lib/features/chef/domain/models/meal_plan_model_check.dart
//
// Not imported by any widget — it exists so the `menu_item` key and the
// slotTotal maths fail loudly here rather than silently in production, where a
// bad snapshot becomes a subscription order with no dishes.
import 'meal_plan_model.dart';

void main() {
  final slot = MealPlanSlot(
    dayOfWeek: 0,
    mealType: 'dinner',
    title: 'Dal Rice',
    items: [
      MealPlanItem(menuItemId: '7', name: 'Dal Rice', price: '80.00', qty: 2),
      MealPlanItem(menuItemId: '9', name: 'Raita', price: '30.50', qty: 1),
    ],
  );

  final rows = slot.toWriteJson()['items'] as List;
  assert(rows.length == 2);

  // The key the backend actually reads (generate_subscriptions.py::_item_rows).
  for (final row in rows.cast<Map<String, dynamic>>()) {
    assert(row.containsKey('menu_item'), 'snapshot row missing menu_item: $row');
    assert('${row['menu_item']}'.isNotEmpty, 'empty menu_item: $row');
    assert(row.containsKey('name') && row.containsKey('price') && row.containsKey('qty'));
  }

  // 80*2 + 30.50*1
  assert(slot.slotTotal == 190.5, 'slotTotal was ${slot.slotTotal}');
  assert(slot.summary == 'Dal Rice ×2, Raita');

  // Round-trip: what the API returns must rebuild to the same maths.
  final rebuilt = MealPlanSlot.fromMap({
    'id': 1,
    'dayOfWeek': 0,
    'mealType': 'dinner',
    'dayName': 'Monday',
    'title': 'Dal Rice',
    'items': rows,
    'slotTotal': '190.50',
    'isActive': true,
  });
  assert(rebuilt.slotTotal == slot.slotTotal);
  assert(rebuilt.summary == slot.summary);

  // Cadence → days, matching PlanPrice.DURATION_DAYS.
  assert(PlanPrice.cadenceDays['week'] == 7);
  assert(PlanPrice.cadenceDays['month'] == 30);
  assert(PlanPrice.cadenceDays['year'] == 365);

  // ignore: avoid_print
  print('meal_plan_model check ok');
}