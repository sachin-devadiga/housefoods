"""Runnable check for the subscription model layer.

    DATABASE_URL=sqlite:///:memory: SECRET_KEY=dev \
        python manage.py test api.tests_subscription -v2

Covers the invariants that three parallel agents are coding against: slot
uniqueness, cadence/price uniqueness, period arithmetic, and the one-meal-one-
order constraint. Money is Decimal and must stay Decimal.
"""

from decimal import Decimal
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from django.contrib.auth.models import User

from .models import (
    UserProfile, Kitchen, MealPlan, PlanPrice, PlanSlot,
    Subscription, SubscriptionMeal, Order,
)


def make_user(email, role='customer'):
    return UserProfile.objects.create(
        user=User.objects.create_user(
            username=email, email=email, password='x',
        ),
        email=email, name=email.split('@')[0], role=role,
    )


class SubscriptionModelTests(TestCase):
    def setUp(self):
        self.chef = make_user('chef@t.dev', 'chef')
        self.customer = make_user('cust@t.dev')
        self.kitchen = Kitchen.objects.create(
            chef=self.chef, name='Test Kitchen', status='approved',
            latitude=12.9716, longitude=77.5946, is_open=True,
        )
        self.plan = MealPlan.objects.create(kitchen=self.kitchen, name='7 Dinner')

    # ── prices ──────────────────────────────────────────────────────────
    def test_one_price_per_cadence(self):
        PlanPrice.objects.create(plan=self.plan, cadence='week', price=Decimal('350'))
        with self.assertRaises(Exception):
            PlanPrice.objects.create(plan=self.plan, cadence='week', price=Decimal('999'))

    def test_price_duration_lookup(self):
        cases = {'week': 7, 'month': 30, 'year': 365}
        for cadence, days in cases.items():
            p = PlanPrice.objects.create(
                plan=self.plan, cadence=cadence, price=Decimal('10'),
            )
            self.assertEqual(p.duration_days, days)

    def test_starting_price_is_cheapest_active(self):
        PlanPrice.objects.create(plan=self.plan, cadence='week', price=Decimal('350'))
        PlanPrice.objects.create(plan=self.plan, cadence='month', price=Decimal('1400'))
        PlanPrice.objects.create(
            plan=self.plan, cadence='year', price=Decimal('99'), is_active=False,
        )
        # Inactive year plan must not undercut the week/month plans.
        self.assertEqual(self.plan.starting_price, Decimal('350'))

    def test_starting_price_none_when_no_prices(self):
        self.assertIsNone(self.plan.starting_price)

    # ── slots ───────────────────────────────────────────────────────────
    def test_one_slot_per_day_and_meal_type(self):
        PlanSlot.objects.create(
            plan=self.plan, day_of_week=0, meal_type='dinner',
            items=[{'name': 'Dal', 'price': '50', 'qty': 1}],
        )
        with self.assertRaises(Exception):
            PlanSlot.objects.create(plan=self.plan, day_of_week=0, meal_type='dinner')

    def test_slot_total_is_decimal(self):
        slot = PlanSlot.objects.create(
            plan=self.plan, day_of_week=2, meal_type='lunch',
            items=[
                {'name': 'Dal', 'price': '50.50', 'qty': 2},
                {'name': 'Rice', 'price': '30.00', 'qty': 1},
            ],
        )
        self.assertIsInstance(slot.slot_total, Decimal)
        self.assertEqual(slot.slot_total, Decimal('131.00'))

    def test_slot_total_ignores_junk_rows(self):
        slot = PlanSlot.objects.create(
            plan=self.plan, day_of_week=3, meal_type='breakfast',
            items=[{'name': 'Idli', 'price': '20', 'qty': 1}, 'garbage', {}],
        )
        self.assertEqual(slot.slot_total, Decimal('20'))

    # ── subscription window ─────────────────────────────────────────────
    def _sub(self, **kw):
        from .models import Address
        addr = Address.objects.create(
            user=self.customer, address_line1='1 Test St',
            city='Bengaluru', latitude=12.97, longitude=77.60,
        )
        defaults = dict(
            customer=self.customer, kitchen=self.kitchen, plan=self.plan,
            cadence='week', address=addr,
            start_date=timezone.now().date(),
            end_date=timezone.now().date() + timedelta(days=7),
        )
        defaults.update(kw)
        return Subscription.objects.create(**defaults)

    def test_extend_rolls_window_forward(self):
        sub = self._sub()
        original_end = sub.end_date
        sub.extend(7)
        sub.refresh_from_db()
        self.assertEqual(sub.end_date, original_end + timedelta(days=7))

    def test_is_current_true_inside_window(self):
        self.assertTrue(self._sub().is_current)

    def test_is_current_false_when_cancelled(self):
        self.assertFalse(self._sub(status='cancelled').is_current)

    def test_is_current_false_when_expired(self):
        past = timezone.now().date() - timedelta(days=30)
        self.assertFalse(self._sub(
            start_date=past - timedelta(days=7), end_date=past,
        ).is_current)

    def test_price_paid_is_decimal_not_float(self):
        sub = self._sub(price_paid=Decimal('1400.50'))
        sub.refresh_from_db()
        self.assertIsInstance(sub.price_paid, Decimal)

    # ── meals ───────────────────────────────────────────────────────────
    def test_one_meal_per_date_and_type(self):
        sub = self._sub()
        today = timezone.now().date()
        SubscriptionMeal.objects.create(
            subscription=sub, date=today, meal_type='dinner',
        )
        with self.assertRaises(Exception):
            SubscriptionMeal.objects.create(
                subscription=sub, date=today, meal_type='dinner',
            )

    def test_same_date_different_meal_types_coexist(self):
        sub = self._sub()
        today = timezone.now().date()
        SubscriptionMeal.objects.create(
            subscription=sub, date=today, meal_type='lunch')
        SubscriptionMeal.objects.create(
            subscription=sub, date=today, meal_type='dinner')
        self.assertEqual(sub.meals.count(), 2)

    def test_meal_defaults_to_scheduled(self):
        sub = self._sub()
        meal = SubscriptionMeal.objects.create(
            subscription=sub, date=timezone.now().date(), meal_type='breakfast')
        self.assertEqual(meal.status, 'scheduled')
        self.assertIsNone(meal.order)

    def test_meal_links_to_exactly_one_order(self):
        sub = self._sub()
        order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('150'), delivery_address='1 Test St',
            order_type='subscription',
        )
        meal = SubscriptionMeal.objects.create(
            subscription=sub, date=timezone.now().date(), meal_type='dinner',
            status='ordered', order=order,
        )
        self.assertEqual(order.subscription_meals.count(), 1)
        self.assertEqual(meal.order, order)

    # ── order side ──────────────────────────────────────────────────────
    def test_order_accepts_subscription_type_and_rider_payout(self):
        order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('150'), delivery_address='1 Test St',
            order_type='subscription',
            delivery_fee=Decimal('42.50'), rider_payout=Decimal('42.50'),
        )
        order.refresh_from_db()
        self.assertEqual(order.order_type, 'subscription')
        self.assertEqual(order.rider_payout, Decimal('42.50'))
        self.assertEqual(order.get_order_type_display(), 'Subscription Meal')

    def test_rider_payout_defaults_to_zero(self):
        order = Order.objects.create(
            customer=self.customer, kitchen=self.kitchen,
            amount=Decimal('150'), delivery_address='1 Test St')
        self.assertEqual(order.rider_payout, Decimal('0.00'))
