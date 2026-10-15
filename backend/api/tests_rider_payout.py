"""Rider earnings and payout, across the two pay models.

    DATABASE_URL=sqlite:///:memory: SECRET_KEY=dev \
        python manage.py test api.tests_rider_payout -v2

Two coexisting pay models, and this file is the seam between them:

  subscription order - customer is charged distance x per-km, rider gets 100%
  one-time order     - customer is charged nothing, rider gets an admin wage

The invariant that matters: every sum a rider can withdraw or see must come
from `Order.rider_payout`, never `Order.delivery_fee`. Using delivery_fee here
would exclude subscription earnings from the payout balance entirely.
"""

from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from django.contrib.auth.models import User
from django.core.management import call_command
from rest_framework.test import APIClient

from .models import UserProfile, Kitchen, Order, AdminSetting


def _mkuser(email, role):
    return UserProfile.objects.create(
        user=User.objects.create_user(username=email, email=email, password='x'),
        email=email, name=email.split('@')[0], role=role,
    )


class RiderPayoutTests(TestCase):
    def setUp(self):
        self.chef = _mkuser('chef@p.dev', 'chef')
        self.customer = _mkuser('cust@p.dev', 'customer')
        self.rider = _mkuser('rider@p.dev', 'delivery_partner')
        # AcceptDeliveryView hard-gates on is_verified. These tests are about
        # the payout arithmetic, not the document review, so pass the gate.
        self.rider.is_verified = True
        self.rider.save()
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='Payout Kitchen', status='approved',
            latitude=12.9716, longitude=77.5946, is_open=True,
        )
        now = timezone.now()
        # Customer paid nothing; rider earned the admin wage.
        self.normal = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('150'), delivery_address='1 St',
            order_type='one_time',
            delivery_fee=Decimal('0.00'), rider_payout=Decimal('30.00'),
            delivery_status='delivered', delivery_partner=self.rider,
            delivered_at=now,
        )
        # Customer charged the distance fee; rider received all of it.
        self.sub = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('240'), delivery_address='1 St',
            order_type='subscription',
            delivery_fee=Decimal('42.50'), rider_payout=Decimal('42.50'),
            delivery_status='delivered', delivery_partner=self.rider,
            delivered_at=now,
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.rider.user)

    def _earnings(self):
        r = self.client.get('/api/auth/delivery/earnings/')
        self.assertEqual(r.status_code, 200, r.data)
        return r.data

    # ── the split ───────────────────────────────────────────────────────
    def test_subscription_and_normal_earnings_are_reported_separately(self):
        d = self._earnings()
        self.assertEqual(Decimal(d['subscription_earnings']), Decimal('42.50'))
        self.assertEqual(Decimal(d['normal_earnings']), Decimal('30.00'))

    def test_total_earnings_equals_the_sum_of_the_two_models(self):
        d = self._earnings()
        self.assertEqual(Decimal(d['total_earnings']), Decimal('72.50'))
        self.assertEqual(
            Decimal(d['total_earnings']),
            Decimal(d['subscription_earnings']) + Decimal(d['normal_earnings']),
        )

    def test_total_earnings_is_not_the_sum_of_delivery_fees(self):
        """delivery_fee alone would total 42.50 and silently drop the wage."""
        d = self._earnings()
        self.assertNotEqual(Decimal(d['total_earnings']), Decimal('42.50'))

    def test_legacy_earnings_keys_still_present(self):
        d = self._earnings()
        for key in ('total_earnings', 'today_earnings', 'weekly_earnings',
                    'total_deliveries'):
            self.assertIn(key, d)

    def test_delivery_count_is_unaffected(self):
        self.assertEqual(self._earnings()['total_deliveries'], 2)

    # ── the payout balance ──────────────────────────────────────────────
    def test_payout_balance_includes_subscription_earnings(self):
        r = self.client.post('/api/auth/delivery/payouts/', {'amount': '500'},
                             format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('72.50', str(r.data))

    def test_payout_below_minimum_is_refused(self):
        r = self.client.post('/api/auth/delivery/payouts/', {'amount': '50'},
                             format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('100', str(r.data))

    # ── accept-time wage ────────────────────────────────────────────────
    def _fresh_pending_order(self, order_type):
        return Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('150'), delivery_address='1 St',
            order_type=order_type, delivery_status='ready_for_delivery',
        )

    def test_accepting_a_one_time_order_sets_the_admin_wage(self):
        order = self._fresh_pending_order('one_time')
        r = self.client.post(f'/api/auth/delivery/{order.pk}/accept/', {},
                             format='json')
        self.assertEqual(r.status_code, 200, r.data)
        order.refresh_from_db()
        self.assertEqual(order.rider_payout,
                         Decimal(AdminSetting.objects.get(
                             key='rider_normal_order_payout').value))

    def test_accepting_a_subscription_order_preserves_the_distance_fee(self):
        """The generator already priced this order. Accept must not overwrite it."""
        order = self._fresh_pending_order('subscription')
        order.delivery_fee = Decimal('77.25')
        order.rider_payout = Decimal('77.25')
        order.save()
        self.client.post(f'/api/auth/delivery/{order.pk}/accept/', {}, format='json')
        order.refresh_from_db()
        self.assertEqual(order.rider_payout, Decimal('77.25'))
        self.assertEqual(order.delivery_fee, Decimal('77.25'))

    def test_missing_admin_setting_falls_back_to_thirty(self):
        AdminSetting.objects.filter(key='rider_normal_order_payout').delete()
        order = self._fresh_pending_order('one_time')
        self.client.post(f'/api/auth/delivery/{order.pk}/accept/', {}, format='json')
        order.refresh_from_db()
        self.assertEqual(order.rider_payout, Decimal('30.00'))

    def test_rider_sees_own_earnings_only(self):
        other = _mkuser('rider2@p.dev', 'delivery_partner')
        Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('99'), delivery_address='1 St',
            order_type='one_time', rider_payout=Decimal('30.00'),
            delivery_status='delivered', delivery_partner=other,
            delivered_at=timezone.now(),
        )
        self.assertEqual(self._earnings()['total_deliveries'], 2)
        self.assertEqual(Decimal(self._earnings()['total_earnings']), Decimal('72.50'))
