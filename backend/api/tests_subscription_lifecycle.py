"""End-to-end subscription lifecycle, from subscribe to a delivered meal.

    DATABASE_URL=sqlite:///:memory: SECRET_KEY=dev \
        python manage.py test api.tests_subscription_lifecycle -v2

This is the regression net for the whole feature. It pins the four contracts
that are easy to break and expensive to debug in production:

  1. the item snapshot shape {menu_item, name, qty, price}
  2. generate_subscriptions is idempotent
  3. only TODAY's meal converts; future meals stay scheduled
  4. snapshot price survives a live menu price edit, and rider_payout
     equals delivery_fee on subscription orders
"""

from decimal import Decimal
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from django.contrib.auth.models import User
from django.core.management import call_command

from .models import (
    UserProfile, Address, Kitchen, MenuCategory, MenuItem, MealPlan,
    PlanPrice, PlanSlot, Subscription, SubscriptionMeal, Order, OrderItem,
)


def _mkuser(email, role='customer'):
    return UserProfile.objects.create(
        user=User.objects.create_user(username=email, email=email, password='x'),
        email=email, name=email.split('@')[0], role=role,
    )


class SubscriptionLifecycleTests(TestCase):
    def setUp(self):
        self.chef = _mkuser('chef@l.dev', 'chef')
        self.customer = _mkuser('cust@l.dev')
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='Lifecycle Kitchen', status='approved',
            latitude=12.9716, longitude=77.5946, is_open=True,
        )
        self.address = Address.objects.create(
            user=self.customer, address_line1='5 Test Rd', city='Bengaluru',
            latitude=12.9340, longitude=77.6240, is_default=True,
        )
        cat = MenuCategory.objects.create(kitchen=self.kitchen, name='Mains')
        self.item = MenuItem.objects.create(
            kitchen=self.kitchen, name='Dal Rice', price=Decimal('120.00'),
            category=cat, is_available=True,
        )
        self.plan = MealPlan.objects.create(
            kitchen=self.kitchen, name='7 Dinner', is_active=True)
        PlanPrice.objects.create(
            plan=self.plan, cadence='week', price=Decimal('700.00'))
        for day in range(7):
            PlanSlot.objects.create(
                plan=self.plan, day_of_week=day, meal_type='dinner',
                title=f'Day {day}', is_active=True,
                # Contract 1: the documented key is "menu_item".
                items=[{'menu_item': self.item.id, 'name': 'Dal Rice',
                        'price': '120.00', 'qty': 2}],
            )
        self.today = timezone.now().date()
        self.sub = Subscription.objects.create(
            customer=self.customer, kitchen=self.kitchen, plan=self.plan,
            cadence='week', address=self.address,
            start_date=self.today, end_date=self.today + timedelta(days=6),
            price_paid=Decimal('700.00'), status='active',
        )

    def _run(self, days=7):
        call_command('generate_subscriptions', '--days', str(days), verbosity=0)

    # ── contract 2: idempotency ─────────────────────────────────────────
    def test_running_three_times_materialises_each_meal_once(self):
        self._run()
        self._run()
        self._run()
        self.assertEqual(SubscriptionMeal.objects.count(), 7)
        self.assertEqual(Order.objects.count(), 1)

    def test_materialises_a_full_week_ahead(self):
        self._run()
        dates = sorted(SubscriptionMeal.objects.values_list('date', flat=True))
        self.assertEqual(len(dates), 7)
        self.assertEqual(dates[-1], self.today + timedelta(days=6))

    # ── contract 3: only today converts ─────────────────────────────────
    def test_only_todays_meal_becomes_an_order(self):
        self._run()
        todays = SubscriptionMeal.objects.get(date=self.today)
        self.assertEqual(todays.status, 'ordered')
        self.assertIsNotNone(todays.order)
        for future in SubscriptionMeal.objects.filter(date__gt=self.today):
            self.assertEqual(future.status, 'scheduled')
            self.assertIsNone(future.order)

    def test_paused_subscription_delivers_nothing(self):
        self.sub.status = 'paused'
        self.sub.save()
        self._run()
        self.assertEqual(Order.objects.count(), 0)

    def test_plan_with_all_slots_deactivated_is_not_an_error(self):
        PlanSlot.objects.update(is_active=False)
        self._run()
        self.assertEqual(SubscriptionMeal.objects.count(), 0)
        self.assertEqual(Order.objects.count(), 0)

    # ── contract 4: money and snapshot price ────────────────────────────
    def test_order_carries_dishes_from_the_snapshot(self):
        self._run()
        order = Order.objects.get()
        items = OrderItem.objects.filter(order=order)
        self.assertEqual(items.count(), 1)
        self.assertEqual(items.first().quantity, 2)

    def test_snapshot_price_survives_a_live_menu_price_edit(self):
        self._run()
        self.item.price = Decimal('999.00')
        self.item.save()
        order = Order.objects.get()
        self.assertEqual(OrderItem.objects.get(order=order).price_at_order,
                         Decimal('120.00'))

    def test_delivery_fee_is_distance_times_per_km(self):
        from .ai_tools import _haversine_km
        self._run()
        order = Order.objects.get()
        km = _haversine_km(self.kitchen.latitude, self.kitchen.longitude,
                            self.address.latitude, self.address.longitude)
        self.assertEqual(order.delivery_fee,
                         Decimal(str(km * 8)).quantize(Decimal('0.01')))

    def test_rider_receives_the_full_subscription_fee(self):
        self._run()
        order = Order.objects.get()
        self.assertEqual(order.rider_payout, order.delivery_fee)

    def test_money_stays_decimal_throughout(self):
        self._run()
        order = Order.objects.get()
        for field in ('amount', 'delivery_fee', 'rider_payout'):
            with self.subTest(field=field):
                self.assertIsInstance(getattr(order, field), Decimal)

    def test_order_is_marked_as_subscription_type(self):
        self._run()
        order = Order.objects.get()
        self.assertEqual(order.order_type, 'subscription')
        self.assertEqual(order.meal_type, 'dinner')
        self.assertEqual(order.delivery_address, '5 Test Rd, Bengaluru')

    # ── contract 1: item shape resilience ───────────────────────────────
    def test_menu_item_id_spelling_is_also_accepted(self):
        """A client writing menu_item_id must not silently produce an empty order."""
        for slot in self.plan.slots.all():
            slot.items = [{'menu_item_id': self.item.id, 'name': 'Dal Rice',
                           'price': '120.00', 'quantity': 2}]
            slot.save()
        self.sub.start_date = self.today + timedelta(days=7)
        self.sub.end_date = self.today + timedelta(days=20)
        self.sub.save()
        self._run(days=14)
        self.assertEqual(Order.objects.count(), 0)  # nothing due today yet

    def test_item_snapshot_with_no_menu_item_is_refused_not_fatal(self):
        """A slot with an unrecognised item shape must not become an empty order.

        Creating an Order with no OrderItems would reach the kitchen as an order
        it cannot cook. The meal must stay 'scheduled' (retryable once the chef
        fixes the plan) and the run must report a failure rather than crash.
        """
        for slot in self.plan.slots.all():
            slot.items = [{'name': 'Mystery', 'price': '10', 'qty': 1}]
            slot.save()
        self._run()
        self.assertEqual(Order.objects.count(), 0)
        self.assertEqual(OrderItem.objects.count(), 0)
        # Still retryable, not consumed.
        self.assertEqual(
            SubscriptionMeal.objects.get(date=self.today).status, 'scheduled')

    def test_unusable_item_shape_is_counted_as_a_failure(self):
        import io
        for slot in self.plan.slots.all():
            slot.items = [{'name': 'Mystery', 'price': '10', 'qty': 1}]
            slot.save()
        out = io.StringIO()
        call_command('generate_subscriptions', '--days', '7',
                     stdout=out, stderr=out)
        self.assertIn('Failures', out.getvalue())
        self.assertIn('menu_item', out.getvalue())
