import os
import json
import logging
import threading
from pathlib import Path

logger = logging.getLogger(__name__)

_firebase_app = None


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
                    channel_id='mealin_orders',
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
    """Send push notification to chef when a new order is placed."""
    if not chef_profile or not chef_profile.fcm_token:
        logger.info('Chef %s has no FCM token, skipping notification', chef_profile)
        return

    send_push_notification(
        tokens=[chef_profile.fcm_token],
        title='New Order Received!',
        body=f'You have a new order #{order.id} for ₹{order.amount}. Tap to view.',
        data={
            'type': 'new_order',
            'order_id': str(order.id),
        },
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
