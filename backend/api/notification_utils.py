import os
import json
import logging
import threading
from pathlib import Path
from django.utils import timezone
from django.utils.formats import date_format
from datetime import timedelta

logger = logging.getLogger(__name__)

_firebase_app = None

# Dedup window: don't send same notification type for same order within this window
DEDUP_WINDOW = timedelta(minutes=2)


def _recent_notification_exists(user, order, notif_type):
    """Check if a notification of this type for this order was sent recently."""
    from .models import Notification
    cutoff = timezone.now() - DEDUP_WINDOW
    return Notification.objects.filter(
        user=user,
        type=notif_type,
        data__order_id=str(order.id),
        created_at__gte=cutoff,
    ).exists()


def _recent_notification_exists_for_data(user, notif_type, data):
    """Dedup guard for notifications that are not tied to an order.

    ``_recent_notification_exists`` keys on ``data__order_id``, which does not
    exist for subscriptions or scheduled meals, so those callers pass the key
    fields they want matched instead. Each key becomes an explicit
    ``data__<key>`` lookup, the same form the order helper uses: the
    ``data__contains`` lookup would be tidier but is not supported on sqlite.
    """
    from .models import Notification
    cutoff = timezone.now() - DEDUP_WINDOW
    return Notification.objects.filter(
        user=user,
        type=notif_type,
        created_at__gte=cutoff,
        **{f'data__{key}': value for key, value in data.items()},
    ).exists()


def _cadence_label(cadence):
    """'week' -> 'Weekly', straight off the model so the wording cannot drift."""
    from .models import PlanPrice
    return PlanPrice.CADENCE_DICT.get(cadence, str(cadence).title())


def _meal_type_label(meal_type):
    """'dinner' -> 'Dinner'."""
    from .models import PlanSlot
    return PlanSlot.MEAL_TYPE_DICT.get(meal_type, str(meal_type).title())


def _day_label(date):
    """Monday-based day name for a date, using the model's own vocabulary."""
    from .models import PlanSlot
    return PlanSlot.DAY_DICT.get(date.weekday(), '')


def _short_date(date):
    """'12 Jun'."""
    return date_format(date, 'j M')


def _get_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    try:
        import firebase_admin
        from firebase_admin import credentials

        service_account_json = os.getenv('FIREBASE_SERVICE_ACCOUNT', '')
        service_account_path = os.getenv(
            'FIREBASE_SERVICE_ACCOUNT_PATH',
            str(Path(__file__).resolve().parent.parent / 'firebase-service-account.json'),
        )

        if service_account_json:
            import json as _json
            cred_dict = _json.loads(service_account_json)
            cred = credentials.Certificate(cred_dict)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info('Firebase Admin SDK initialized from env var')
        elif os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info('Firebase Admin SDK initialized from %s', service_account_path)
        else:
            logger.warning('No Firebase credentials found')
            return None
    except Exception:
        logger.exception('Failed to initialize Firebase Admin SDK')
        return None

    return _firebase_app


def send_push_notification(tokens, title, body, data=None):
    """Send a push notification to a list of FCM tokens in the background."""
    if not tokens:
        return

    filtered = [t for t in tokens if t]
    if not filtered:
        return

    thread = threading.Thread(
        target=_send_push_sync,
        args=(filtered, title, body, data or {}),
        daemon=True,
    )
    thread.start()


def _send_push_sync(tokens, title, body, data):
    try:
        app = _get_firebase_app()
        if app is None:
            logger.warning('Firebase not initialized, skipping push notification')
            return

        from firebase_admin import messaging

        notif_type = data.get('type', '') if isinstance(data, dict) else ''
        is_alarm = notif_type in ('new_order', 'new_delivery')
        channel_id = 'mealin_order_alarm' if is_alarm else 'mealin_orders'

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data,
            tokens=tokens,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id=channel_id,
                    priority='MAX',
                    default_sound=True,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    ),
                ),
            ),
        )

        response = messaging.send_each_for_multicast(message)
        logger.info(
            'Push notification sent: %d success, %d failure out of %d total',
            response.success_count, response.failure_count, len(tokens),
        )

        if response.failure_count > 0:
            for i, resp in enumerate(response.responses):
                if not resp.success:
                    logger.warning('Push failed for token %s: %s', tokens[i][:20], resp.exception)
    except Exception:
        logger.exception('Failed to send push notification')


def notify_chef_new_order(chef_profile, order):
    """Send push notification and create DB record when chef receives a new order."""
    from .models import Notification

    if not chef_profile:
        return

    if _recent_notification_exists(chef_profile, order, 'new_order'):
        logger.info('Dedup: skipping duplicate new_order for chef, order %s', order.id)
        return

    title = 'New Order Received!'
    body = f'You have a new order #{order.id} for ₹{order.amount}. Tap to view.'
    data = {
        'type': 'new_order',
        'order_id': str(order.id),
    }

    Notification.objects.create(
        user=chef_profile,
        title=title,
        body=body,
        type='new_order',
        data=data,
    )

    if chef_profile.fcm_token:
        send_push_notification(
            tokens=[chef_profile.fcm_token],
            title=title,
            body=body,
            data=data,
        )


def notify_delivery_partners(order, delivery_profiles):
    """Send push notification to delivery partners when an order is ready for delivery."""
    tokens = [p.fcm_token for p in delivery_profiles if p.fcm_token]
    if not tokens:
        logger.info('No delivery partners with FCM tokens for order %s', order.id)
        return

    send_push_notification(
        tokens=tokens,
        title='New Delivery Available!',
        body=f'Delivery opportunity from order #{order.id}. Tap to accept.',
        data={
            'type': 'new_delivery',
            'order_id': str(order.id),
        },
    )


def notify_customer_order_status(order, status_text):
    """Notify customer when their order status changes."""
    from .models import Notification

    customer = order.customer
    notif_key = f'order_status_{status_text}'

    if _recent_notification_exists(customer, order, notif_key):
        logger.info('Dedup: skipping duplicate order_status_%s for order %s', status_text, order.id)
        return

    title = 'Order Status Update'
    body = f'Your order #{order.id} from {order.kitchen.name} is now {status_text}.'
    data = {
        'type': 'order_status',
        'order_id': str(order.id),
        'status': status_text,
    }

    Notification.objects.create(
        user=customer,
        title=title,
        body=body,
        type=notif_key,
        data=data,
    )

    if customer.fcm_token:
        send_push_notification(
            tokens=[customer.fcm_token],
            title=title,
            body=body,
            data=data,
        )


def notify_customer_delivery_eta(order, eta_minutes):
    """Notify customer when delivery is approximately ETA minutes away."""
    from .models import Notification

    customer = order.customer

    # Use the model-level dedup flag as primary guard
    if getattr(order, 'eta_5min_notified', False):
        logger.info('Dedup: eta_5min_notified already True for order %s', order.id)
        return

    title = 'Delivery Update'
    body = f'Your order #{order.id} from {order.kitchen.name} is approximately {eta_minutes} minutes away.'
    data = {
        'type': 'delivery_eta',
        'order_id': str(order.id),
        'eta_minutes': str(eta_minutes),
    }

    Notification.objects.create(
        user=customer,
        title=title,
        body=body,
        type='delivery_eta',
        data=data,
    )

    if customer.fcm_token:
        send_push_notification(
            tokens=[customer.fcm_token],
            title=title,
            body=body,
            data=data,
        )


def notify_restaurant_new_order(restaurant_profile, order):
    """Enhanced version of notify_chef_new_order with restaurant name."""
    from .models import Notification

    chef = restaurant_profile
    if not chef:
        return

    if _recent_notification_exists(chef, order, 'new_order'):
        logger.info('Dedup: skipping duplicate new_order for restaurant, order %s', order.id)
        return

    title = f'New Order at {order.kitchen.name}!'
    body = f'New order #{order.id} for ₹{order.amount}. Tap to view and prepare.'
    data = {
        'type': 'new_order',
        'order_id': str(order.id),
        'restaurant_name': order.kitchen.name,
    }

    Notification.objects.create(
        user=chef,
        title=title,
        body=body,
        type='new_order',
        data=data,
    )

    if chef.fcm_token:
        send_push_notification(
            tokens=[chef.fcm_token],
            title=title,
            body=body,
            data=data,
        )


def notify_restaurant_order_cancelled(chef_profile, order):
    """Notify restaurant when a customer cancels an order."""
    from .models import Notification

    if not chef_profile:
        return

    if _recent_notification_exists(chef_profile, order, 'order_cancelled'):
        logger.info('Dedup: skipping duplicate order_cancelled for order %s', order.id)
        return

    title = 'Order Cancelled'
    body = f'Order #{order.id} (₹{order.amount}) has been cancelled by the customer.'
    data = {
        'type': 'order_cancelled',
        'order_id': str(order.id),
    }

    Notification.objects.create(
        user=chef_profile,
        title=title,
        body=body,
        type='order_cancelled',
        data=data,
    )

    if chef_profile.fcm_token:
        send_push_notification(
            tokens=[chef_profile.fcm_token],
            title=title,
            body=body,
            data=data,
        )


def notify_delivery_partner_accepted(order):
    """Notify customer when a delivery partner accepts their order."""
    from .models import Notification

    customer = order.customer

    if _recent_notification_exists(customer, order, 'delivery_assigned'):
        logger.info('Dedup: skipping duplicate delivery_assigned for order %s', order.id)
        return

    rider_name = order.delivery_partner.name if order.delivery_partner else 'A delivery partner'
    title = 'Delivery Partner Assigned'
    body = f'{rider_name} has accepted your order #{order.id}. They will pick it up shortly.'
    data = {
        'type': 'delivery_assigned',
        'order_id': str(order.id),
    }

    Notification.objects.create(
        user=customer,
        title=title,
        body=body,
        type='delivery_assigned',
        data=data,
    )

    if customer.fcm_token:
        send_push_notification(
            tokens=[customer.fcm_token],
            title=title,
            body=body,
            data=data,
        )


# ---------------------------------------------------------------------------
# Subscriptions
#
# Same shape as the order notifications above: guard on a dedup key, write the
# Notification row, then push only when there is an fcm_token. These are called
# from inside the subscribe transaction and from the nightly materialiser, so
# every one is wrapped in try/except and returns quietly - a failed notification
# must never roll back a purchase or drop a generated order.
# ---------------------------------------------------------------------------

def notify_chef_new_subscription(chef_profile, subscription):
    """Tell the chef someone just committed to their plan."""
    sub_id = getattr(subscription, 'id', None)
    try:
        from .models import Notification

        if not chef_profile:
            return

        if _recent_notification_exists_for_data(
            chef_profile, 'new_subscription', {'subscription_id': str(sub_id)},
        ):
            logger.info('Dedup: skipping duplicate new_subscription for chef, subscription %s', sub_id)
            return

        customer = subscription.customer
        plan_name = subscription.plan.name
        cadence = _cadence_label(subscription.cadence)
        start = _short_date(subscription.start_date)
        meals_per_week = subscription.plan.slots.filter(is_active=True).count()
        customer_label = customer.name or customer.email

        title = 'New Subscription!'
        body = (
            f'{customer_label} subscribed to {plan_name} ({cadence}) for '
            f'₹{subscription.price_paid}. Starts {start}, {meals_per_week} meals per week.'
        )
        data = {
            'type': 'new_subscription',
            'subscription_id': str(sub_id),
            'plan_name': plan_name,
            'cadence': subscription.cadence,
            'amount': str(subscription.price_paid),
        }

        Notification.objects.create(
            user=chef_profile,
            title=title,
            body=body,
            type='new_subscription',
            data=data,
        )

        if chef_profile.fcm_token:
            send_push_notification(
                tokens=[chef_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to notify chef of new subscription %s', sub_id)
        return


def notify_customer_subscription_confirmed(customer_profile, subscription):
    """Confirm the purchase and say what happens next."""
    sub_id = getattr(subscription, 'id', None)
    try:
        from .models import Notification

        if not customer_profile:
            return

        if _recent_notification_exists_for_data(
            customer_profile, 'subscription_confirmed', {'subscription_id': str(sub_id)},
        ):
            logger.info('Dedup: skipping duplicate subscription_confirmed for subscription %s', sub_id)
            return

        kitchen_name = subscription.kitchen.name
        start = _short_date(subscription.start_date)

        title = 'Subscription Confirmed'
        body = (
            f'Your {subscription.plan.name} plan with {kitchen_name} is confirmed. '
            f'{kitchen_name} prepares your meals each week, and your first delivery '
            f'lands on {start}.'
        )
        data = {
            'type': 'subscription_confirmed',
            'subscription_id': str(sub_id),
            'plan_name': subscription.plan.name,
            'kitchen_name': kitchen_name,
            'start_date': str(subscription.start_date),
        }

        Notification.objects.create(
            user=customer_profile,
            title=title,
            body=body,
            type='subscription_confirmed',
            data=data,
        )

        if customer_profile.fcm_token:
            send_push_notification(
                tokens=[customer_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to confirm subscription %s to customer', sub_id)
        return


def notify_customer_meal_skipped(customer_profile, subscription, meal):
    """Acknowledge one skipped meal by naming its date and meal type."""
    sub_id = getattr(subscription, 'id', None)
    meal_id = getattr(meal, 'id', None)
    try:
        from .models import Notification

        if not customer_profile:
            return

        if _recent_notification_exists_for_data(
            customer_profile,
            'subscription_meal_skipped',
            {
                'subscription_id': str(sub_id),
                'meal_date': str(meal.date),
                'meal_type': str(meal.meal_type),
            },
        ):
            logger.info('Dedup: skipping duplicate subscription_meal_skipped for meal %s', meal_id)
            return

        day = _day_label(meal.date)
        title = 'Meal Skipped'
        body = (
            f'Your {day} {_meal_type_label(meal.meal_type).lower()} on '
            f'{_short_date(meal.date)} has been skipped.'
        )
        data = {
            'type': 'subscription_meal_skipped',
            'subscription_id': str(sub_id),
            'meal_date': str(meal.date),
            'meal_type': str(meal.meal_type),
        }

        Notification.objects.create(
            user=customer_profile,
            title=title,
            body=body,
            type='subscription_meal_skipped',
            data=data,
        )

        if customer_profile.fcm_token:
            send_push_notification(
                tokens=[customer_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to notify customer of skipped meal %s', meal_id)
        return


def notify_customer_subscription_updated(customer_profile, subscription, change):
    """Announce a pause, resume or cancellation and say when deliveries move."""
    sub_id = getattr(subscription, 'id', None)
    try:
        from .models import Notification

        if not customer_profile:
            return

        if _recent_notification_exists_for_data(
            customer_profile, 'subscription_updated', {'subscription_id': str(sub_id)},
        ):
            logger.info('Dedup: skipping duplicate subscription_updated for subscription %s', sub_id)
            return

        change = str(change or '').strip().lower()
        plan_name = subscription.plan.name

        if change == 'cancelled':
            body = (
                f'Your {plan_name} subscription is cancelled. '
                f'No further meals will be delivered after {_short_date(subscription.end_date)}.'
            )
        elif change == 'paused':
            body = (
                f'Your {plan_name} subscription is paused. No meals will be delivered '
                f'while it is paused, and deliveries resume as soon as you restart it.'
            )
        else:
            resume = subscription.meals.filter(
                status='scheduled', date__gte=timezone.now().date(),
            ).order_by('date').values_list('date', flat=True).first()
            resume_on = _short_date(resume) if resume else _short_date(subscription.start_date)
            body = (
                f'Your {plan_name} subscription is {change}. '
                f'Deliveries resume on {resume_on}.'
            )

        title = 'Subscription Update'
        data = {
            'type': 'subscription_updated',
            'subscription_id': str(sub_id),
            'change': change,
            'status': str(subscription.status),
        }

        Notification.objects.create(
            user=customer_profile,
            title=title,
            body=body,
            type='subscription_updated',
            data=data,
        )

        if customer_profile.fcm_token:
            send_push_notification(
                tokens=[customer_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to notify customer of subscription update %s', sub_id)
        return


def notify_customer_subscription_renewed(customer_profile, subscription, price):
    """Confirm a billing period rolled over and what was charged."""
    sub_id = getattr(subscription, 'id', None)
    try:
        from .models import Notification

        if not customer_profile:
            return

        if _recent_notification_exists_for_data(
            customer_profile, 'subscription_renewed', {'subscription_id': str(sub_id)},
        ):
            logger.info('Dedup: skipping duplicate subscription_renewed for subscription %s', sub_id)
            return

        period_start = getattr(subscription, 'period_start', None) or subscription.start_date
        title = 'Subscription Renewed'
        body = (
            f'Your {subscription.plan.name} plan renewed for '
            f'{_short_date(period_start)} to {_short_date(subscription.end_date)}. '
            f'₹{price} charged.'
        )
        data = {
            'type': 'subscription_renewed',
            'subscription_id': str(sub_id),
            'plan_name': subscription.plan.name,
            'period_start': str(period_start),
            'period_end': str(subscription.end_date),
            'amount': str(price),
        }

        Notification.objects.create(
            user=customer_profile,
            title=title,
            body=body,
            type='subscription_renewed',
            data=data,
        )

        if customer_profile.fcm_token:
            send_push_notification(
                tokens=[customer_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to notify customer of renewal for subscription %s', sub_id)
        return


def notify_chef_upcoming_meals(chef_profile, subscription, meals):
    """One daily digest of everything due, grouped by date. Never N pushes."""
    sub_id = getattr(subscription, 'id', None)
    try:
        from .models import Notification

        if not chef_profile:
            return

        if _recent_notification_exists_for_data(
            chef_profile, 'upcoming_meals', {'subscription_id': str(sub_id)},
        ):
            logger.info('Dedup: skipping duplicate upcoming_meals for chef, subscription %s', sub_id)
            return

        by_date = {}
        for meal in meals:
            by_date.setdefault(meal.date, []).append(meal)

        if not by_date:
            logger.info('No upcoming meals for subscription %s, nothing to digest', sub_id)
            return

        summary = '; '.join(
            f'{_day_label(date)} {_short_date(date)}: '
            f'{", ".join(sorted(_meal_type_label(m.meal_type) for m in by_date[date]))}'
            for date in sorted(by_date)
        )
        total = sum(len(v) for v in by_date.values())
        customer = subscription.customer
        customer_label = customer.name or customer.email

        title = 'Upcoming Subscription Meals'
        body = f'{total} meal(s) to prepare for {customer_label} - {summary}.'
        data = {
            'type': 'upcoming_meals',
            'subscription_id': str(sub_id),
            'customer_name': customer_label,
            'meal_count': str(total),
        }

        Notification.objects.create(
            user=chef_profile,
            title=title,
            body=body,
            type='upcoming_meals',
            data=data,
        )

        if chef_profile.fcm_token:
            send_push_notification(
                tokens=[chef_profile.fcm_token],
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception('Failed to build upcoming meals digest for subscription %s', sub_id)
        return
