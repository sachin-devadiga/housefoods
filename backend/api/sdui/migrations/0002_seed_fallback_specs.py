"""Seed the fallback SDUI specs.

Every key in `schema.DEFAULTS` becomes an `is_fallback=True, is_active=False`
row. Two reasons this matters:

1. An admin has something to copy and edit rather than authoring a spec blind.
2. The fallback chain in `api/sdui/views.py` is active spec -> fallback row ->
   baked-in default. Seeding the middle layer means an admin can override a
   fallback without touching code.

Idempotent: `get_or_create` on the unique key, so re-running on a partially
seeded database is safe.

Depends on 0001 because the seeded rows are ScreenDefinition.
"""
from django.db import migrations

# Kept inline rather than imported from schema.py: a migration must keep
# producing the same result even if the schema module changes later. If you
# change schema.DEFAULTS, add a NEW migration rather than editing this one.
SEED = {
    'customer_home': {
        'key': 'customer_home',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'column',
            'gap': 16,
            'padding': {'all': 16},
            'children': [
                {
                    'type': 'banner_carousel',
                    'id': 'home_promos',
                    'height': 160,
                    'banners': [
                        {
                            'id': 'welcome',
                            'title': 'Home-cooked, delivered',
                            'subtitle': 'Fresh meals from kitchens near you',
                        },
                    ],
                },
                {
                    'type': 'section',
                    'id': 'kitchens_near_you',
                    'title': 'Kitchens near you',
                    'children': [
                        {
                            'type': 'text',
                            'text': 'Browse home kitchens and their daily menus.',
                            'style': 'body',
                        },
                    ],
                },
            ],
        },
    },
    'banners': {
        'key': 'banners',
        'version': 1,
        'schema_version': 1,
        # Zero-height spacer = "no opinion". See the note in schema.py: a
        # populated fallback here would render on every install, because this
        # row IS what the fallback chain serves when no active spec exists.
        'root': {'type': 'spacer', 'height': 0},
    },
    'onboarding': {
        'key': 'onboarding',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'column',
            'gap': 16,
            'padding': {'all': 24},
            'children': [
                {'type': 'text', 'text': 'Discover home kitchens near you',
                 'style': 'h2'},
                {'type': 'text',
                 'text': 'Real home cooks, fresh meals, delivered fast.',
                 'style': 'body'},
            ],
        },
    },
    'login': {
        'key': 'login',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'column',
            'gap': 16,
            'padding': {'all': 24},
            'children': [
                {'type': 'text', 'text': 'Welcome to MealIn', 'style': 'h1'},
                {'type': 'text',
                 'text': 'Enter your email and we will send a one-time code.',
                 'style': 'body'},
                {'type': 'button', 'label': 'Send OTP', 'variant': 'primary',
                 'action': {'type': 'none'}},
            ],
        },
    },
    'kitchen_details': {
        'key': 'kitchen_details',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'column',
            'gap': 12,
            'padding': {'all': 16},
            'children': [
                {'type': 'text', 'text': "Today's menu", 'style': 'h3'},
                {'type': 'dish_row', 'name': 'Home-cooked meal',
                 'description': 'Prepared fresh in a local kitchen',
                 'price': '0', 'available': True},
            ],
        },
    },
    'customer_nav': {
        'key': 'customer_nav',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'list',
            'children': [
                {'type': 'container', 'id': 'nav_home',
                 'on_tap': {'type': 'open_screen', 'value': 'home'}},
                {'type': 'container', 'id': 'nav_orders',
                 'on_tap': {'type': 'open_screen', 'value': 'orders'}},
                {'type': 'container', 'id': 'nav_search',
                 'on_tap': {'type': 'open_screen', 'value': 'search'}},
                {'type': 'container', 'id': 'nav_subscriptions',
                 'on_tap': {'type': 'open_screen', 'value': 'subscriptions'}},
                {'type': 'container', 'id': 'nav_profile',
                 'on_tap': {'type': 'open_screen', 'value': 'profile'}},
            ],
        },
    },
    'chef_nav': {
        'key': 'chef_nav',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'list',
            'children': [
                {'type': 'container', 'id': 'chef_dashboard',
                 'on_tap': {'type': 'open_screen', 'value': 'dashboard'}},
            ],
        },
    },
    'delivery_nav': {
        'key': 'delivery_nav',
        'version': 1,
        'schema_version': 1,
        'root': {
            'type': 'list',
            'children': [
                {'type': 'container', 'id': 'rider_dashboard',
                 'on_tap': {'type': 'open_screen', 'value': 'dashboard'}},
            ],
        },
    },
}


def seed(apps, schema_editor):
    ScreenDefinition = apps.get_model('sdui', 'ScreenDefinition')
    for spec in SEED.values():
        ScreenDefinition.objects.get_or_create(
            key=spec['key'],
            defaults={
                'role': 'all',
                'version': spec['version'],
                'spec': spec,
                'is_active': False,
                'is_fallback': True,
            },
        )


def unseed(apps, schema_editor):
    ScreenDefinition = apps.get_model('sdui', 'ScreenDefinition')
    ScreenDefinition.objects.filter(
        key__in=SEED, is_fallback=True, is_active=False,
    ).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('sdui', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]