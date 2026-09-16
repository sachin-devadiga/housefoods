import os
import json
import logging
import threading
from pathlib import Path
from django.utils import timezone
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
