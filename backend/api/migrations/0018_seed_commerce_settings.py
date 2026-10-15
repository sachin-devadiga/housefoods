"""Seed the admin-controlled commerce rates.

Idempotent: get_or_create on the unique key, so re-running or applying on top
of a partially seeded database is safe. Values are deliberately starting
points, not policy — admins edit them in Django admin from here on.
"""

from django.db import migrations

DEFAULTS = [
    # Rs per km for subscription deliveries. Rider receives 100% of the
    # resulting fee; the platform takes no cut on subscription delivery.
    ('delivery_fee_per_km', '8'),
    # Rs the rider earns per delivered ONE-TIME order. The customer is not
    # charged a delivery fee on one-time orders; this is a platform-paid wage.
    ('rider_normal_order_payout', '30'),
    # Minimum days between subscribing and the first meal. Drives how far
    # ahead generate_subscriptions materialises SubscriptionMeal rows.
    ('subscription_min_lead_days', '7'),
    # Base component of the subscription delivery fee. 0 = purely distance
    # based, per current pricing decision.
    ('delivery_fee_base', '0'),
]


def seed(apps, schema_editor):
    AdminSetting = apps.get_model('api', 'AdminSetting')
    for key, value in DEFAULTS:
        AdminSetting.objects.get_or_create(key=key, defaults={'value': value})


def unseed(apps, schema_editor):
    AdminSetting = apps.get_model('api', 'AdminSetting')
    AdminSetting.objects.filter(key__in=[k for k, _ in DEFAULTS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0017_order_rider_payout_alter_order_order_type_mealplan_and_more'),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
