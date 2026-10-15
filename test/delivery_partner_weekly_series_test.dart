import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/features/delivery_partner/presentation/providers/delivery_partner_provider.dart';

void main() {
  group('DeliveryPartnerProvider.weeklySeriesFrom', () {
    // Wed 2026-10-07. Week starts Mon 2026-10-05, so index 2 is "today".
    final now = DateTime(2026, 10, 7, 12);

    test('buckets payouts by delivered_at day, Mon-first', () {
      final series = DeliveryPartnerProvider.weeklySeriesFrom([
        {'delivered_at': '2026-10-05 09:00:00', 'rider_payout': '40.00'},
        {'delivered_at': '2026-10-07 18:00:00', 'rider_payout': 25.5},
        {'delivered_at': '2026-10-07 19:00:00', 'rider_payout': 14.5},
      ], now);

      expect(series.length, 7);
      expect(series[0]['day'], 'Mon');
      expect(series[0]['amount'], 40.0);
      expect(series[2]['day'], 'Wed');
      expect(series[2]['amount'], 40.0); // 25.5 + 14.5
      expect(series[3]['amount'], 0.0);
      expect(series.map((d) => d['day']).toList(),
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    });

    test('drops deliveries outside the current week', () {
      final series = DeliveryPartnerProvider.weeklySeriesFrom([
        {'delivered_at': '2026-10-01 10:00:00', 'rider_payout': '99.00'},
        {'delivered_at': '2026-10-12 10:00:00', 'rider_payout': '99.00'},
      ], now);

      expect(series.every((d) => d['amount'] == 0.0), isTrue);
    });

    test('skips malformed rows instead of throwing', () {
      final series = DeliveryPartnerProvider.weeklySeriesFrom([
        {'delivered_at': null, 'rider_payout': '50.00'},
        {'rider_payout': '50.00'},
        {'delivered_at': '2026-10-07 10:00:00', 'rider_payout': null},
      ], now);

      expect(series[2]['amount'], 0.0);
    });

    test('empty history yields a zeroed week, never an invented line', () {
      final series = DeliveryPartnerProvider.weeklySeriesFrom([], now);
      expect(series.length, 7);
      expect(series.every((d) => d['amount'] == 0.0), isTrue);
    });
  });
}