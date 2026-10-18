"""Cash-on-delivery settlement rules.

COD introduced a money correctness problem: an order is created before any
cash exists, so counting it as revenue or paying it out immediately would
move money that was never collected. These tests pin the three rules agreed
for COD:

  1. wallet credit cannot be combined with cash on delivery
  2. a COD order is settled by the rider at handover, not at creation
  3. payout requires BOTH delivered and paid
"""
from decimal import Decimal

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from django.contrib.auth.models import User
from api.models import Kitchen, MenuItem, Order, UserProfile
from api.serializers import OrderCreateSerializer


def _mkuser(email, role):
    """UserProfile is one-to-one with auth.User; JWT auth needs both."""
    user = User.objects.create_user(username=email, email=email, password='x')
    return UserProfile.objects.create(
        user=user, uid=email, email=email,
        name=email.split('@')[0], role=role,
    )


class PaymentStateTests(TestCase):
    def setUp(self):
        self.chef = _mkuser('chef-cod@test', 'chef')
        self.customer = _mkuser('cust-cod@test', 'customer')
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='COD Kitchen', status='approved', is_open=True,
            address='Somewhere', latitude=13.0, longitude=77.0,
        )

    def _order(self, **kw):
        defaults = dict(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('100.00'), delivery_address='addr',
        )
        defaults.update(kw)
        return Order.objects.create(**defaults)

    # --- rule 3: payout eligibility -------------------------------------

    def test_unpaid_cod_order_is_not_payout_eligible(self):
        order = self._order(payment_method='cod', is_paid=False)
        self.assertFalse(order.payout_eligible)

    def test_paid_but_undelivered_cod_order_is_not_payout_eligible(self):
        # Cash may be collected early, but the meal has not arrived yet.
        order = self._order(
            payment_method='cod', is_paid=True, delivery_status='picked_up')
        self.assertFalse(order.payout_eligible)

    def test_delivered_and_paid_cod_order_is_payout_eligible(self):
        order = self._order(
            payment_method='cod', is_paid=True, delivery_status='delivered')
        self.assertTrue(order.payout_eligible)

    def test_delivered_but_unpaid_order_is_not_payout_eligible(self):
        # The exact failure this feature exists to prevent.
        order = self._order(
            payment_method='cod', is_paid=False, delivery_status='delivered')
        self.assertFalse(order.payout_eligible)

    def test_online_delivered_order_remains_eligible(self):
        order = self._order(
            payment_method='online', is_paid=True, delivery_status='delivered')
        self.assertTrue(order.payout_eligible)

    def test_is_cod_flag(self):
        self.assertTrue(self._order(payment_method='cod').is_cod)
        self.assertFalse(self._order(payment_method='online').is_cod)

    # --- rule 1: wallet + COD --------------------------------------------

    def test_wallet_plus_cod_is_rejected(self):
        s = OrderCreateSerializer(
            data={
                'kitchen': self.kitchen.id, 'order_type': 'one_time',
                'amount': '100.00', 'delivery_address': 'addr',
                'payment_method': 'cod',
            },
            context={'request': None, 'wallet_deduction': Decimal('50')},
        )
        self.assertFalse(s.is_valid())
        self.assertIn('payment_method', s.errors)

    def test_cod_without_wallet_is_accepted(self):
        s = OrderCreateSerializer(
            data={
                'kitchen': self.kitchen.id, 'order_type': 'one_time',
                'amount': '100.00', 'delivery_address': 'addr',
                'payment_method': 'cod',
            },
            context={'request': None, 'wallet_deduction': Decimal('0')},
        )
        self.assertTrue(s.is_valid(), s.errors)

    def test_online_with_wallet_is_still_accepted(self):
        s = OrderCreateSerializer(
            data={
                'kitchen': self.kitchen.id, 'order_type': 'one_time',
                'amount': '100.00', 'delivery_address': 'addr',
                'payment_method': 'online',
            },
            context={'request': None, 'wallet_deduction': Decimal('50')},
        )
        self.assertTrue(s.is_valid(), s.errors)


class RiderSettlementTests(TestCase):
    """Rule 2: the rider's delivery confirmation settles the cash."""

    def setUp(self):
        self.chef = _mkuser('chef-r@test', 'chef')
        self.customer = _mkuser('cust-r@test', 'customer')
        self.rider = _mkuser('rider-r@test', 'delivery_partner')
        self.rider.is_verified = True
        self.rider.save()
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='K', status='approved', is_open=True,
            address='a', latitude=1.0, longitude=1.0)
        self.client = APIClient()

    def _token(self, profile):
        from rest_framework_simplejwt.tokens import AccessToken
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {AccessToken.for_user(profile.user)}')

    def test_rider_delivery_marks_cod_paid(self):
        order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('100.00'), delivery_address='a',
            payment_method='cod', is_paid=False,
            delivery_partner=self.rider, delivery_status='picked_up',
            delivery_otp='123456',
        )
        self._token(self.rider)
        url = f'/api/auth/delivery/{order.id}/status/'
        res = self.client.post(url, {'delivery_status': 'delivered', 'otp': '123456'})
        self.assertEqual(res.status_code, 200, res.data)
        order.refresh_from_db()
        self.assertEqual(order.delivery_status, 'delivered')
        self.assertTrue(order.is_paid)
        self.assertIsNotNone(order.paid_at)

    def test_delivery_with_wrong_otp_does_not_settle(self):
        order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('100.00'), delivery_address='a',
            payment_method='cod', is_paid=False,
            delivery_partner=self.rider, delivery_status='picked_up',
            delivery_otp='123456',
        )
        self._token(self.rider)
        url = f'/api/auth/delivery/{order.id}/status/'
        res = self.client.post(url, {'delivery_status': 'delivered', 'otp': '000000'})
        self.assertEqual(res.status_code, 400)
        order.refresh_from_db()
        self.assertFalse(order.is_paid)


class AdminOverrideTests(TestCase):
    def setUp(self):
        self.chef = _mkuser('chef-a@test', 'chef')
        self.customer = _mkuser('cust-a@test', 'customer')
        self.admin = _mkuser('adm@test', 'admin')
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='K', status='approved', is_open=True,
            address='a', latitude=1.0, longitude=1.0)
        self.order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('100.00'), delivery_address='a',
            payment_method='cod', is_paid=False, delivery_status='delivered')
        self.client = APIClient()

    def _token(self, profile):
        from rest_framework_simplejwt.tokens import AccessToken
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {AccessToken.for_user(profile.user)}')

    def test_admin_can_mark_paid(self):
        self._token(self.admin)
        res = self.client.post(
            f'/api/auth/admin/orders/{self.order.id}/payment/',
            {'is_paid': True}, format='json')
        self.assertEqual(res.status_code, 200, res.data)
        self.order.refresh_from_db()
        self.assertTrue(self.order.is_paid)
        self.assertIsNotNone(self.order.paid_at)

    def test_admin_can_reverse(self):
        self.order.is_paid = True
        self.order.paid_at = timezone.now()
        self.order.save()
        self._token(self.admin)
        res = self.client.post(
            f'/api/auth/admin/orders/{self.order.id}/payment/',
            {'is_paid': False}, format='json')
        self.assertEqual(res.status_code, 200, res.data)
        self.order.refresh_from_db()
        self.assertFalse(self.order.is_paid)
        self.assertIsNone(self.order.paid_at)

    def test_non_admin_is_rejected(self):
        self._token(self.customer)
        res = self.client.post(
            f'/api/auth/admin/orders/{self.order.id}/payment/',
            {'is_paid': True}, format='json')
        self.assertIn(res.status_code, (401, 403))
        self.order.refresh_from_db()
        self.assertFalse(self.order.is_paid)

    def test_missing_is_paid_is_rejected(self):
        self._token(self.admin)
        res = self.client.post(
            f'/api/auth/admin/orders/{self.order.id}/payment/',
            {}, format='json')
        self.assertEqual(res.status_code, 400)


class OrderCreationTests(TestCase):
    def setUp(self):
        self.chef = _mkuser('chef-c@test', 'chef')
        self.customer = _mkuser('cust-c@test', 'customer')
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='K', status='approved', is_open=True,
            address='a', latitude=1.0, longitude=1.0)
        self.dish = MenuItem.objects.create(
            kitchen=self.kitchen, name='Dal Rice', price=Decimal('100.00'))
        self.client = APIClient()
        from rest_framework_simplejwt.tokens import AccessToken
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {AccessToken.for_user(self.customer.user)}')

    def _items(self):
        return [{'menu_item': self.dish.id, 'quantity': 1,
                 'special_instructions': ''}]

    def test_cod_order_starts_unpaid(self):
        res = self.client.post('/api/auth/orders/place/', {
            'kitchen': self.kitchen.id, 'order_type': 'one_time',
            'amount': '100.00', 'delivery_address': 'a',
            'payment_method': 'cod', 'items_data': self._items(),
        }, format='json')
        self.assertEqual(res.status_code, 201, res.data)
        order = Order.objects.latest('id')
        self.assertEqual(order.payment_method, 'cod')
        self.assertFalse(order.is_paid)
        self.assertIsNone(order.paid_at)

    def test_online_order_defaults_paid(self):
        res = self.client.post('/api/auth/orders/place/', {
            'kitchen': self.kitchen.id, 'order_type': 'one_time',
            'amount': '100.00', 'delivery_address': 'a',
            'payment_method': 'online', 'items_data': self._items(),
        }, format='json')
        self.assertEqual(res.status_code, 201, res.data)
        order = Order.objects.latest('id')
        self.assertEqual(order.payment_method, 'online')
        self.assertTrue(order.is_paid)

    def test_cod_with_wallet_is_rejected_by_endpoint(self):
        res = self.client.post('/api/auth/orders/place-with-wallet/', {
            'kitchen': self.kitchen.id, 'order_type': 'one_time',
            'amount': '100.00', 'delivery_address': 'a',
            'payment_method': 'cod', 'wallet_deduction': '10.00',
            'items_data': self._items(),
        }, format='json')
        self.assertEqual(res.status_code, 400)
        self.assertIn('wallet', str(res.data).lower())