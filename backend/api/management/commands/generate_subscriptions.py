"""Materialise recurring subscription meals and convert the due ones to Orders.

Two phases, both idempotent:

  Phase 1  materialise SubscriptionMeal rows up to N days ahead from each
           active subscription's weekly plan template (PlanSlot).
  Phase 2  convert today's still-'scheduled' SubscriptionMeal rows into real
           Orders via OrderCreateSerializer — the same creation path the REST
           API uses.

Idempotency comes from the DB, not from a read-then-write check:
`uniq_sub_meal (subscription, date, meal_type)` makes Phase 1 a get_or_create,
and Phase 2 only ever looks at meals still in status='scheduled' inside the
same transaction that flips them to 'ordered'. Run it twice, get the same rows.

Usage:
    python manage.py generate_subscriptions
    python manage.py generate_subscriptions --days 30      # backfill a new sub
    python manage.py generate_subscriptions --road-distance
"""

import math
import logging
from datetime import timedelta
from decimal import Decimal, InvalidOperation

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from api.models import (
    AdminSetting, OrderItem, PlanSlot, Subscription, SubscriptionMeal,
)
from api.notification_utils import notify_chef_new_order
from api.serializers import OrderCreateSerializer

logger = logging.getLogger(__name__)

EARTH_RADIUS_KM = 6371.0
OSRM_BASE = 'https://router.project-osrm.org/route/v1/driving'
DEFAULT_LEAD_DAYS = 7
OSRM_TIMEOUT = 10


def _haversine_km(lat1, lon1, lat2, lon2):
    """Straight-line distance in km. Pure Python, no network, no PostGIS."""
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(d_lon / 2) ** 2)
    return EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _setting(key, default):
    """Read an AdminSetting as Decimal, falling back to the seeded default."""
    row = AdminSetting.objects.filter(key=key).values_list('value', flat=True).first()
    if row is None:
        return default
    try:
        return Decimal(str(row))
    except (InvalidOperation, ValueError, TypeError):
        return default


def _usable_coords(lat, lon):
    """Reject (0, 0) — that is the model default meaning 'never geocoded'."""
    try:
        lat_f, lon_f = float(lat), float(lon)
    except (TypeError, ValueError):
        return None
    if math.isnan(lat_f) or math.isnan(lon_f):
        return None
    if lat_f == 0.0 and lon_f == 0.0:
        return None
    if not (-90.0 <= lat_f <= 90.0 and -180.0 <= lon_f <= 180.0):
        return None
    return lat_f, lon_f


def _road_distance_km(kitchen, address):
    """Opt-in OSRM road distance.

    Off by default on purpose: router.project-osrm.org is a free public demo
    API with no key and no SLA. One call per meal per day will rate-limit and
    then stall deliveries, and a stalled delivery costs far more than the few
    percent a straight-line fee differs by. Use --road-distance for one-off
    backfills or a self-hosted OSRM; switch to a contracted provider (Google/
    Mapbox/Valhalla) before running this in production on real volume.
    """
    import requests  # imported lazily: the default path needs no network stack

    start = _usable_coords(kitchen.latitude, kitchen.longitude)
    end = _usable_coords(address.latitude, address.longitude)
    if not start or not end:
        return None
    url = f'{OSRM_BASE}/{start[1]},{start[0]};{end[1]},{end[0]}?overview=false'
    resp = requests.get(url, timeout=OSRM_TIMEOUT)
    resp.raise_for_status()
    data = resp.json()
    if data.get('code') != 'Ok' or not data.get('routes'):
        raise ValueError('no route found')
    return data['routes'][0]['distance'] / 1000.0


def _address_text(addr):
    return ', '.join(p for p in (
        addr.address_line1, addr.address_line2, addr.landmark,
        addr.city, addr.state, addr.pincode,
    ) if p)


def _item_rows(meal):
    """Map a meal's frozen items snapshot onto OrderItem kwargs.

    The snapshot shape is {menu_item, name, qty, price} (see PlanSlot). We
    prefer the snapshotted price so that a later menu price edit does not
    retroactively change what the subscriber signed up for; the live menu price
    is the fallback when the snapshot predates pricing.

    A row without a usable ``menu_item`` is dropped, but loudly. Silently
    skipping produces an Order with no dishes, which reaches the kitchen as an
    order it cannot cook — the worst possible failure for this feature. The
    chef plan builder is a separate deployment surface, so a shape mismatch
    there must surface here as a log line and a counted failure, not an order
    with an empty basket.
    """
    rows = []
    for idx, item in enumerate(meal.items or []):
        if not isinstance(item, dict):
            logger.warning(
                'SubscriptionMeal %s item %d is %r, expected a dict; skipped',
                getattr(meal, 'id', None), idx, type(item).__name__,
            )
            continue
        # Accept the documented key, plus the two obvious spellings a client
        # may send. Anything else is a contract violation worth shouting about.
        menu_item_id = (
            item.get('menu_item') or item.get('menu_item_id') or item.get('menuItem')
        )
        if not menu_item_id:
            logger.warning(
                'SubscriptionMeal %s item %d has no menu item id (keys=%s); skipped. '
                'Snapshot must use "menu_item".',
                getattr(meal, 'id', None), idx, sorted(item.keys()),
            )
            continue
        try:
            qty = int(item.get('qty') or item.get('quantity') or 1)
        except (TypeError, ValueError):
            qty = 1
        rows.append({
            'menu_item_id': menu_item_id,
            'quantity': max(qty, 1),
            'snapshot_price': item.get('price'),
        })
    return rows


class FakeRequest:
    """Minimal stand-in for the request OrderCreateSerializer expects.

    The serializer resolves the order's customer from
    ``self.context['request'].user.profile``. Rather than fork that logic (and
    risk the kitchen/rider sides drifting from the REST path), hand it the one
    attribute chain it touches.
    """

    def __init__(self, profile):
        self.user = type('_User', (), {'profile': profile})()


class Command(BaseCommand):
    help = 'Materialise upcoming subscription meals and convert due meals into Orders'

    def add_arguments(self, parser):
        parser.add_argument(
            '--days', type=int, default=None,
            help=f'Days to materialise ahead (default: AdminSetting '
                 f'subscription_min_lead_days, else {DEFAULT_LEAD_DAYS})',
        )
        parser.add_argument(
            '--road-distance', action='store_true',
            help='Use OSRM road distance for the delivery fee instead of '
                 'straight-line Haversine. Off by default: the public OSRM '
                 'endpoint is rate-limited and has no SLA.',
        )

    def handle(self, *args, **options):
        today = timezone.now().date()
        days = options['days'] or int(_setting('subscription_min_lead_days', DEFAULT_LEAD_DAYS))
        days = max(days, 0)
        road_distance = options['road_distance']

        per_km = _setting('delivery_fee_per_km', Decimal('8'))
        base_fee = _setting('delivery_fee_base', Decimal('0'))

        subs = Subscription.objects.filter(
            status='active', start_date__lte=today, end_date__gte=today,
        ).select_related('plan', 'kitchen', 'address')

        stats = {
            'scanned': subs.count(),
            'materialised': 0,
            'existing': 0,
            'orders': 0,
            'skipped_inactive': 0,
            'failures': [],
        }

        self.stdout.write(
            f'Window {today} -> {today + timedelta(days=days - 1) if days else today} '
            f'({days} day(s)) | fee {per_km}/km + {base_fee} base | '
            f'distance={"OSRM road" if road_distance else "haversine"}'
        )

        self._materialise(subs, today, days, stats)
        self._convert(today, stats, per_km, base_fee, road_distance)

        self.stdout.write('')
        self.stdout.write('=' * 52)
        self.stdout.write(f'Subscriptions scanned : {stats["scanned"]}')
        self.stdout.write(f'Meals materialised    : {stats["materialised"]} '
                          f'(already present: {stats["existing"]})')
        self.stdout.write(f'Orders created        : {stats["orders"]}')
        self.stdout.write(f'Meals skipped (paused): {stats["skipped_inactive"]}')
        self.stdout.write(f'Failures              : {len(stats["failures"])}')
        for label, detail in stats['failures']:
            self.stdout.write(self.style.WARNING(f'  - {label}: {detail}'))
        self.stdout.write('=' * 52)

    # ------------------------------------------------------------------
    # Phase 1
    # ------------------------------------------------------------------
    def _materialise(self, subs, today, days, stats):
        """Create SubscriptionMeal rows for each matching active PlanSlot.

        One query for all slots of a plan, grouped by day_of_week, instead of
        one query per date per slot.
        """
        if days <= 0:
            return

        for sub in subs:
            window_end = min(today + timedelta(days=days - 1), sub.end_date)
            if window_end < sub.start_date:
                continue

            slots_by_day = {}
            for slot in PlanSlot.objects.filter(plan=sub.plan, is_active=True):
                slots_by_day.setdefault(slot.day_of_week, []).append(slot)
            if not slots_by_day:
                # A plan with every slot deactivated legitimately yields zero
                # meals. That is correct, not an error.
                continue

            offset = (sub.start_date - today).days
            for day_offset in range(max(offset, 0), (window_end - today).days + 1):
                date = today + timedelta(days=day_offset)
                for slot in slots_by_day.get(date.weekday(), []):
                    _, created = SubscriptionMeal.objects.get_or_create(
                        subscription=sub,
                        date=date,
                        meal_type=slot.meal_type,
                        defaults={
                            'slot': slot,
                            'title': slot.title,
                            'items': slot.items,
                            'status': 'scheduled',
                        },
                    )
                    if created:
                        stats['materialised'] += 1
                    else:
                        stats['existing'] += 1

    # ------------------------------------------------------------------
    # Phase 2
    # ------------------------------------------------------------------
    def _convert(self, today, stats, per_km, base_fee, road_distance):
        meals = SubscriptionMeal.objects.filter(
            status='scheduled', date=today,
        ).select_related(
            'subscription', 'subscription__plan', 'subscription__kitchen',
            'subscription__address', 'subscription__customer',
        )

        for meal in meals:
            sub = meal.subscription
            if sub.status != 'active':
                stats['skipped_inactive'] += 1
                continue
            # transaction.atomic() per order: one bad meal must not roll back
            # the whole run.
            try:
                with transaction.atomic():
                    # Re-read under the transaction: status may have flipped
                    # (e.g. a concurrent run converted it a moment ago).
                    meal = SubscriptionMeal.objects.select_for_update().get(pk=meal.pk)
                    if meal.status != 'scheduled':
                        continue

                    fee, note = self._delivery_fee(sub, per_km, base_fee, road_distance)
                    if fee is None:
                        raise ValueError('unusable kitchen/address coordinates')
                    if note:
                        self.stdout.write(self.style.WARNING(f'  ~ meal {meal.pk}: {note}'))

                    order = self._build_order(sub, meal, fee)

                    meal.order = order
                    meal.status = 'ordered'
                    meal.save(update_fields=['order', 'status', 'updated_at'])
                    stats['orders'] += 1

                # Push is best-effort and must not undo a committed order.
                try:
                    notify_chef_new_order(sub.kitchen.chef, order)
                except Exception as exc:  # noqa: BLE001
                    self.stderr.write(f'  ! chef notify failed for order {order.id}: {exc}')
            except Exception as exc:  # noqa: BLE001
                stats['failures'].append(
                    (f'meal {meal.pk} (sub {sub.pk})', f'{type(exc).__name__}: {exc}')
                )

    def _delivery_fee(self, sub, per_km, base_fee, road_distance):
        """Return (Decimal fee, fallback note or None).

        Straight-line Haversine is the default and the fallback: a distance
        failure must never cost the customer their meal.
        """
        kitchen, address = sub.kitchen, sub.address

        if road_distance:
            try:
                km = _road_distance_km(kitchen, address)
                if km is None:
                    raise ValueError('unusable coordinates for road distance')
                return _money(Decimal(str(km)) * per_km + base_fee), None
            except Exception as exc:  # noqa: BLE001
                note = f'road distance failed ({type(exc).__name__}: {exc}); fell back to straight-line'
        else:
            note = None

        start = _usable_coords(kitchen.latitude, kitchen.longitude)
        end = _usable_coords(address.latitude, address.longitude)
        if not start or not end:
            return None, note
        km = _haversine_km(start[0], start[1], end[0], end[1])
        return _money(Decimal(str(km)) * per_km + base_fee), note

    def _build_order(self, sub, meal, fee):
        rows = _item_rows(meal)
        # Refuse to create an order the kitchen cannot cook. Leaving the meal
        # 'scheduled' keeps it retryable once the chef fixes the plan, and the
        # failure is counted so it shows up in the run summary rather than
        # silently becoming an empty order.
        if not rows:
            raise ValueError(
                f'slot has no usable items (expected "menu_item" in each '
                f'snapshot row, got keys={sorted(meal.items[0].keys()) if meal.items else []})'
            )

        items_data = [
            {'menu_item': row['menu_item_id'], 'quantity': row['quantity']}
            for row in rows
        ]
        subtotal = Decimal(str(meal.item_total))

        payload = {
            'kitchen': sub.kitchen_id,
            'order_type': 'subscription',
            'amount': subtotal,
            'subtotal': subtotal,
            'tax': Decimal('0.00'),
            'platform_fee': Decimal('0.00'),
            'tip': Decimal('0.00'),
            'delivery_address': _address_text(sub.address),
            'delivery_time': timezone.now(),
            'start_date': meal.date,
            'end_date': meal.date,
            'meal_type': meal.meal_type,
            'items_data': items_data,
            'delivery_latitude': sub.address.latitude or None,
            'delivery_longitude': sub.address.longitude or None,
        }

        serializer = OrderCreateSerializer(
            data=payload, context={'request': FakeRequest(sub.customer)}
        )
        serializer.is_valid(raise_exception=True)
        order = serializer.save()

        # delivery_fee / rider_payout are not in OrderCreateSerializer.Meta.fields,
        # so they are set after creation. Rider receives 100% of the
        # subscription delivery fee — firm product decision, no platform cut.
        order.delivery_fee = fee
        order.rider_payout = fee
        order.save(update_fields=['delivery_fee', 'rider_payout', 'updated_at'])

        # OrderCreateSerializer.create() only writes OrderItem rows for
        # order_type='one_time' (serializers.py:241). A subscription order would
        # otherwise reach the kitchen with no items, so write them here from the
        # same snapshot. get_or_create keeps this idempotent if it ever re-runs.
        for row in rows:
            menu_item = row['menu_item_id']
            price = row['snapshot_price']
            try:
                price = Decimal(str(price))
            except (InvalidOperation, ValueError, TypeError):
                pass
            else:
                if price <= 0:
                    price = None
            if price is None:
                from api.models import MenuItem
                price = MenuItem.objects.values_list('price', flat=True).get(pk=menu_item)
            OrderItem.objects.get_or_create(
                order=order, menu_item_id=menu_item,
                defaults={'quantity': row['quantity'], 'price_at_order': price},
            )

        return order


def _money(value):
    """Decimal, 2dp. Never float for money."""
    return Decimal(str(value)).quantize(Decimal('0.01'))