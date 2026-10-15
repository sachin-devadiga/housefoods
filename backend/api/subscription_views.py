"""Customer-facing subscription API.

Lives in its own module rather than views.py: that file is large and is being
edited concurrently by other agents. Everything here is customer-scoped —
plan discovery, checkout, and lifecycle control of one's own subscriptions.

Money is Decimal end to end. Delivery fee is always returned as its own line
so the Flutter checkout can show the customer what they are paying for,
instead of one opaque total.
"""

import logging
from datetime import datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import notification_utils
from .ai_tools import _haversine_km
from .models import (
    Address, AdminSetting, MealPlan, PlanPrice, Subscription, SubscriptionMeal,
)
from .serializers import MealPlanSerializer, SubscriptionSerializer

logger = logging.getLogger(__name__)

DEFAULT_RADIUS_KM = 15.0

# Fallbacks mirror migration 0018's seeded values. A missing AdminSetting row
# must degrade to a sane number, never raise.
SETTING_DEFAULTS = {
    'delivery_fee_per_km': Decimal('8'),
    'delivery_fee_base': Decimal('0'),
    'subscription_min_lead_days': 7,
}


# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

def admin_setting(key, default):
    """Read an AdminSetting as Decimal (or int for a day count).

    A missing row, a blank value, or unparsable junk all fall back to the
    caller's default rather than raising — a bad config must not 500 checkout.
    """
    raw = AdminSetting.objects.filter(key=key).values_list(
        'value', flat=True).first()
    if raw is None or str(raw).strip() == '':
        return default
    try:
        return int(raw) if isinstance(default, int) and not isinstance(default, bool) \
            else Decimal(str(raw))
    except (TypeError, ValueError, ArithmeticError):
        logger.warning('AdminSetting %s has unusable value %r, using default', key, raw)
        return default


def distance_km(lat1, lon1, lat2, lon2):
    """Great-circle distance in km.

    Reuses the existing pure-Python haversine in ai_tools rather than adding a
    PostGIS dependency: the project must run on SQLite (tests) and
    MySQL/Postgres (prod), and no portable SQL would beat this for the handful
    of kitchens inside a radius.
    """
    return round(_haversine_km(float(lat1), float(lon1), float(lat2), float(lon2)), 2)


def _has_coords(obj):
    """latitude/longitude default to 0.0, so 0,0 means 'never geocoded'."""
    return not (float(obj.latitude) == 0.0 and float(obj.longitude) == 0.0)


def source_address(profile):
    """Default address, else the first one."""
    return (profile.addresses.filter(is_default=True).first()
            or profile.addresses.first())


def _input(request, key):
    """Read a field from the body, falling back to the query string."""
    return request.data.get(key, request.query_params.get(key))


def _notify(func_name, *args, **kwargs):
    """Cross-agent notification helper.

    notification_utils is being extended in parallel; a function that is absent
    or raises must never take down the subscription that triggered it.
    """
    func = getattr(notification_utils, func_name, None)
    if func is None:
        logger.warning('notification_utils.%s not available yet, skipping', func_name)
        return
    try:
        func(*args, **kwargs)
    except Exception:
        logger.exception('notification %s failed', func_name)


class _PlanCardSerializer(MealPlanSerializer):
    """MealPlanSerializer with starting_price read off the prefetch cache.

    The model property runs a fresh query per instance (``self.prices.filter``),
    which turns the plan list into an N+1. Same value, no query.
    """

    starting_price = serializers.SerializerMethodField()

    def get_starting_price(self, obj):
        active = [p.price for p in obj.prices.all() if p.is_active]
        return str(min(active)) if active else None


class _BaseSubscriptionView(APIView):
    permission_classes = [IsAuthenticated]

    def get_subscription(self, request, pk):
        try:
            subscription = Subscription.objects.select_related(
                'kitchen', 'plan', 'address',
            ).prefetch_related('meals').get(pk=pk)
        except Subscription.DoesNotExist:
            return None, Response(
                {'error': 'Subscription not found'}, status=status.HTTP_404_NOT_FOUND,
            )
        profile = request.user.profile
        if subscription.customer_id != profile.id:
            return None, Response(
                {'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN,
            )
        return subscription, None

    def set_status(self, request, pk, new_status, required_status):
        """Shared by pause/resume: only a subscription in ``required_status`` moves."""
        subscription, error = self.get_subscription(request, pk)
        if error:
            return error
        if subscription.status != required_status:
            return Response(
                {'error': f'Subscription is already {subscription.status}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        subscription.status = new_status
        subscription.save(update_fields=['status', 'updated_at'])
        return Response(SubscriptionSerializer(subscription).data)


# ──────────────────────────────────────────────
# PLAN DISCOVERY
# ──────────────────────────────────────────────

class SubscriptionPlanListView(_BaseSubscriptionView):
    """Active plans from approved, open kitchens, nearest first."""

    def get(self, request):
        address = source_address(request.user.profile)
        if not address:
            return Response(
                {'error': 'Add a delivery address before browsing plans'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            radius = float(request.query_params.get('radius_km', DEFAULT_RADIUS_KM))
        except (TypeError, ValueError):
            radius = DEFAULT_RADIUS_KM

        located = _has_coords(address)
        plans = MealPlan.objects.filter(
            is_active=True,
            kitchen__status='approved',
            kitchen__is_open=True,
        ).select_related('kitchen').prefetch_related('prices', 'slots')

        results = []
        for plan in plans:
            if located:
                dist = distance_km(address.latitude, address.longitude,
                                   plan.kitchen.latitude, plan.kitchen.longitude)
                if dist > radius:
                    continue
                plan.distance_km = dist
            else:
                plan.distance_km = None
            results.append(_PlanCardSerializer(plan).data)

        results.sort(key=lambda r: (r['distance_km'] is None, r['distance_km'] or 0))
        return Response({'results': results})


class SubscriptionQuoteView(_BaseSubscriptionView):
    """Transparent cost breakdown for the checkout screen.

    The delivery fee is deliberately a separate line, not folded into the
    total: the customer sees exactly what the plan costs and what delivery adds.
    """

    def get(self, request):
        return self._quote(request)

    def post(self, request):
        return self._quote(request)

    def _quote(self, request):
        price_id = _input(request, 'price')
        address_id = _input(request, 'address')
        if not price_id or not address_id:
            return Response(
                {'error': 'price and address are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            plan_price = PlanPrice.objects.select_related('plan__kitchen').get(pk=price_id)
            address = Address.objects.get(pk=address_id)
        except (PlanPrice.DoesNotExist, Address.DoesNotExist):
            return Response(
                {'error': 'Unknown price or address'}, status=status.HTTP_404_NOT_FOUND,
            )

        if address.user_id != request.user.profile.id:
            return Response(
                {'error': 'Address does not belong to you'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if _has_coords(address) and _has_coords(plan_price.plan.kitchen):
            dist = distance_km(address.latitude, address.longitude,
                               plan_price.plan.kitchen.latitude,
                               plan_price.plan.kitchen.longitude)
        else:
            dist = None

        per_km = admin_setting('delivery_fee_per_km', SETTING_DEFAULTS['delivery_fee_per_km'])
        base = admin_setting('delivery_fee_base', SETTING_DEFAULTS['delivery_fee_base'])
        # Charge on the rounded distance so the number the customer sees and the
        # number they are billed are the same number.
        billed_km = Decimal(str(dist)) if dist is not None else Decimal('0')
        delivery_fee = (base + per_km * billed_km).quantize(
            Decimal('0.01'), rounding=ROUND_HALF_UP)

        active_slots = plan_price.plan.slots.filter(is_active=True).count()
        duration_days = plan_price.duration_days
        # The slot template is weekly, so scale it to the billing period.
        # A 7-dinner plan therefore yields 7 / 30 / 365 meals for week/month/year.
        meals_per_period = int(active_slots * duration_days / 7)

        plan_price_decimal = Decimal(plan_price.price)
        return Response({
            'plan_price': str(plan_price_decimal),
            'cadence': plan_price.cadence,
            'duration_days': duration_days,
            'meals_per_period': meals_per_period,
            'delivery_fee_per_km': str(per_km),
            'distance_km': dist,
            'delivery_fee_total': str(delivery_fee),
            'period_total': str((plan_price_decimal + delivery_fee).quantize(
                Decimal('0.01'), rounding=ROUND_HALF_UP)),
            'currency': 'INR',
        })


# ──────────────────────────────────────────────
# SUBSCRIBE
# ──────────────────────────────────────────────

class SubscribeView(_BaseSubscriptionView):
    def post(self, request):
        plan_id = _input(request, 'plan')
        price_id = _input(request, 'price')
        address_id = _input(request, 'address')
        start_date_raw = _input(request, 'start_date')

        missing = [n for n, v in (
            ('plan', plan_id), ('price', price_id),
            ('address', address_id), ('start_date', start_date_raw),
        ) if not v]
        if missing:
            return Response(
                {'error': f'Missing required fields: {", ".join(missing)}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            plan = MealPlan.objects.select_related('kitchen').get(pk=plan_id)
        except (MealPlan.DoesNotExist, ValueError):
            return Response({'error': 'Plan not found'}, status=status.HTTP_404_NOT_FOUND)

        if not plan.is_active:
            return Response({'error': 'This plan is no longer available'},
                            status=status.HTTP_400_BAD_REQUEST)
        if plan.kitchen.status != 'approved' or not plan.kitchen.is_open:
            return Response({'error': 'This kitchen is not accepting subscriptions'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            plan_price = PlanPrice.objects.get(pk=price_id, plan=plan)
        except (PlanPrice.DoesNotExist, ValueError):
            return Response({'error': 'Price not found for this plan'},
                            status=status.HTTP_404_NOT_FOUND)
        if not plan_price.is_active:
            return Response({'error': 'This price is no longer available'},
                            status=status.HTTP_400_BAD_REQUEST)

        profile = request.user.profile
        try:
            address = Address.objects.get(pk=address_id, user=profile)
        except (Address.DoesNotExist, ValueError):
            return Response({'error': 'Address not found'},
                            status=status.HTTP_404_NOT_FOUND)

        try:
            start_date = datetime.strptime(str(start_date_raw)[:10], '%Y-%m-%d').date()
        except ValueError:
            return Response({'error': 'start_date must be YYYY-MM-DD'},
                            status=status.HTTP_400_BAD_REQUEST)

        min_lead = admin_setting('subscription_min_lead_days',
                                 SETTING_DEFAULTS['subscription_min_lead_days'])
        earliest = timezone.now().date() + timedelta(days=min_lead)
        if start_date < earliest:
            return Response(
                {'error': f'Start date must be at least {min_lead} days from today '
                          f'(earliest {earliest.isoformat()})'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        end_date = start_date + timedelta(days=plan_price.duration_days - 1)

        with transaction.atomic():
            subscription = Subscription.objects.create(
                customer=profile,
                kitchen=plan.kitchen,
                plan=plan,
                cadence=plan_price.cadence,
                address=address,
                start_date=start_date,
                end_date=end_date,
                status='active',
                price_paid=plan_price.price,
                # Razorpay checkout is completed and verified client-side; the
                # backend only records the id it is handed. No signature check.
                payment_id=request.data.get('payment_id', '') or '',
                period_start=start_date,
                last_charged_at=timezone.now(),
            )

        _notify('notify_chef_new_subscription', plan.kitchen.chef, subscription)

        return Response(
            SubscriptionSerializer(subscription).data, status=status.HTTP_201_CREATED)


# ──────────────────────────────────────────────
# MY SUBSCRIPTIONS
# ──────────────────────────────────────────────

class MySubscriptionsView(_BaseSubscriptionView):
    def get(self, request):
        subscriptions = Subscription.objects.filter(
            customer=request.user.profile,
        ).select_related('kitchen', 'plan', 'address').prefetch_related(
            'meals',
        ).order_by('-created_at')
        return Response({'results': SubscriptionSerializer(
            subscriptions, many=True).data})


# ──────────────────────────────────────────────
# LIFECYCLE
# ──────────────────────────────────────────────

class SubscriptionPauseView(_BaseSubscriptionView):
    def post(self, request, pk):
        return self.set_status(request, pk, 'paused', 'active')


class SubscriptionResumeView(_BaseSubscriptionView):
    def post(self, request, pk):
        return self.set_status(request, pk, 'active', 'paused')


class SubscriptionCancelView(_BaseSubscriptionView):
    def post(self, request, pk):
        subscription, error = self.get_subscription(request, pk)
        if error:
            return error
        if subscription.status == 'cancelled':
            return Response(SubscriptionSerializer(subscription).data)
        subscription.status = 'cancelled'
        subscription.save(update_fields=['status', 'updated_at'])
        return Response(SubscriptionSerializer(subscription).data)


class SubscriptionSkipMealView(_BaseSubscriptionView):
    def post(self, request, pk):
        subscription, error = self.get_subscription(request, pk)
        if error:
            return error
        if subscription.status != 'active':
            return Response(
                {'error': f'Cannot skip a meal on a {subscription.status} subscription'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        date_raw = _input(request, 'date')
        meal_type = _input(request, 'meal_type')
        if not date_raw or not meal_type:
            return Response(
                {'error': 'date and meal_type are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            meal_date = datetime.strptime(str(date_raw)[:10], '%Y-%m-%d').date()
        except ValueError:
            return Response({'error': 'date must be YYYY-MM-DD'},
                            status=status.HTTP_400_BAD_REQUEST)

        if meal_date <= timezone.now().date():
            return Response({'error': 'Can only skip a future meal'},
                            status=status.HTTP_400_BAD_REQUEST)

        try:
            meal = subscription.meals.get(date=meal_date, meal_type=meal_type)
        except SubscriptionMeal.DoesNotExist:
            return Response({'error': 'No such meal on this subscription'},
                            status=status.HTTP_404_NOT_FOUND)

        if meal.status != 'scheduled':
            return Response(
                {'error': f'This meal is already {meal.status}'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        meal.status = 'skipped'
        meal.skip_reason = str(request.data.get('reason', '') or '')[:255]
        meal.save(update_fields=['status', 'skip_reason', 'updated_at'])

        _notify('notify_customer_meal_skipped', subscription.customer, subscription, meal)

        return Response(SubscriptionSerializer(subscription).data)
