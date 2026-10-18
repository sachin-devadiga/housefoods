"""The SDUI spec contract: JSON Schema validation plus baked-in DEFAULTS.

This module is the single source of truth for what a spec may contain. The Dart
client in `lib/core/sdui/sdui_widget_registry.dart` implements the same node
types; if you add a type here you must add a builder there, and the test
`test/sdui_registry_test.dart` asserts the two stay in step.

Design rules, all enforced here rather than in the client:

1. A spec that fails `validate_spec` can never be published. Validation runs in
   `ScreenDefinition.clean()` / `save()`, so a malformed spec is rejected at
   authoring time instead of surfacing as a broken screen on a user's phone.
2. Unknown node types are a validation ERROR, not a warning. A typo like
   `banner_carosel` must not silently render nothing.
3. `DEFAULTS` below are the backend's own fallback. If the database is empty,
   every endpoint still returns a renderable answer. The Dart client keeps its
   own copy of equivalent defaults, so there are two independent fallbacks and a
   database outage cannot produce a blank screen.
"""
import copy

SCHEMA_VERSION = 1

ACTION_TYPES = ['open_url', 'open_screen', 'dismiss', 'none']

TEXT_STYLES = ['h1', 'h2', 'h3', 'body', 'caption']
BUTTON_VARIANTS = ['primary', 'secondary', 'ghost', 'danger']

# Types that hold children. Everything else is a leaf.
CONTAINER_TYPES = ['column', 'row', 'container', 'section', 'list', 'grid']

# Types that REQUIRE children. `container` is deliberately absent: it is the
# tap-target primitive used for nav items and cards, which are legitimately
# childless (`{"type":"container","id":"nav_home","on_tap":{...}}`).
LAYOUT_TYPES = ['column', 'row', 'section', 'list', 'grid']

ALL_TYPES = CONTAINER_TYPES + [
    'text',
    'button',
    'banner_carousel',
    'promo_banner',
    'kitchen_card',
    'dish_row',
    'divider',
    'spacer',
]

_ACTION = {
    'type': 'object',
    'properties': {
        'type': {'type': 'string', 'enum': ACTION_TYPES},
        'value': {'type': 'string'},
    },
    'required': ['type'],
    'additionalProperties': False,
}

_PADDING = {
    'type': 'object',
    'properties': {
        'all': {'type': 'number', 'minimum': 0, 'maximum': 128},
        'left': {'type': 'number', 'minimum': 0, 'maximum': 128},
        'right': {'type': 'number', 'minimum': 0, 'maximum': 128},
        'top': {'type': 'number', 'minimum': 0, 'maximum': 128},
        'bottom': {'type': 'number', 'minimum': 0, 'maximum': 128},
    },
    'additionalProperties': False,
}

_BANNER = {
    'type': 'object',
    'properties': {
        'id': {'type': 'string'},
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
        'image_url': {'type': 'string'},
        'action': _ACTION,
    },
    'required': ['id', 'title'],
    'additionalProperties': False,
}

# Icons an author may name. This is a CLOSED set on purpose: the client maps
# these strings to Material icons, so an unknown name is a validation error
# rather than a blank space. Adding a name here plus a mapping in
# lib/core/sdui/sdui_widget_registry.dart is the extension path for icons.
# (Note: SDUI can only *compose* capabilities the client already ships. A brand
# new widget type still needs an app release; what SDUI buys is rearranging and
# re-labelling what already exists.)
ICONS = [
    'storefront', 'shopping_bag', 'bolt', 'mic', 'repeat',
    'restaurant', 'delivery', 'star', 'favorite', 'schedule',
    'search', 'location', 'wallet', 'gift', 'support',
    'restaurant_menu', 'eco', 'verified', 'local_offer', 'schedule_send',
]


# Per-type field rules. Anything not listed is rejected (additionalProperties
# False below), so a misspelled field is caught at authoring time.
_TYPE_FIELDS = {
    'column': {
        'children': True, 'padding': True, 'gap': True, 'cross_axis_align': True,
    },
    'row': {
        'children': True, 'padding': True, 'gap': True, 'cross_axis_align': True,
    },
    'container': {
        'children': True, 'padding': True, 'background_color': True,
        'border_radius': True, 'on_tap': True, 'icon': True, 'action': True,
    },
    'section': {
        'children': True, 'title': True, 'subtitle': True, 'collapsible': True,
        'padding': True,
    },
    'text': {
        'text': True, 'style': True, 'color': True, 'align': True, 'max_lines': True,
        'icon': True,
    },
    'button': {
        'label': True, 'action': True, 'variant': True, 'enabled': True,
        'icon': True,
    },
    'banner_carousel': {
        'banners': True, 'height': True, 'autoplay_interval_ms': True,
    },
    'promo_banner': {
        'id': True, 'title': True, 'subtitle': True, 'image_url': True,
        'background_color': True, 'action': True, 'height': True, 'icon': True,
    },
    'kitchen_card': {
        'kitchen_id': True, 'show_rating': True, 'show_distance': True,
        'image_url': True, 'name': True,
    },
    'dish_row': {
        'dish_id': True, 'name': True, 'description': True, 'price': True,
        'image_url': True, 'available': True, 'action': True, 'icon': True,
    },
    'list': {'children': True, 'item_builder_hint': True},
    'grid': {'children': True, 'columns': True},
    'divider': {'height': True, 'color': True},
    'spacer': {'height': True},
}

# Fields every node may carry.
_COMMON_FIELDS = {'id', 'type'}


def _node_schema():
    """A recursive node schema. `$ref` keeps it finite."""
    return {
        'type': 'object',
        'required': ['type'],
        'additionalProperties': False,
        'properties': {
            'type': {'type': 'string', 'enum': ALL_TYPES},
            'id': {'type': 'string'},
            'children': {
                'type': 'array',
                'items': {'$ref': '#/definitions/node'},
            },
            'padding': _PADDING,
            'gap': {'type': 'number', 'minimum': 0, 'maximum': 128},
            'cross_axis_align': {
                'type': 'string',
                'enum': ['start', 'center', 'end', 'stretch'],
            },
            'background_color': {'type': 'string'},
            'border_radius': {'type': 'number', 'minimum': 0, 'maximum': 64},
            'color': {'type': 'string'},
            'height': {'type': 'number', 'minimum': 0, 'maximum': 2000},
            'on_tap': _ACTION,
            'action': _ACTION,
            'title': {'type': 'string'},
            'subtitle': {'type': 'string'},
            'collapsible': {'type': 'boolean'},
            'text': {'type': 'string'},
            'style': {'type': 'string', 'enum': TEXT_STYLES},
            'align': {
                'type': 'string',
                'enum': ['left', 'center', 'right', 'justify'],
            },
            'max_lines': {'type': 'integer', 'minimum': 1, 'maximum': 20},
            'label': {'type': 'string'},
            'variant': {'type': 'string', 'enum': BUTTON_VARIANTS},
            'enabled': {'type': 'boolean'},
            'autoplay_interval_ms': {'type': 'integer', 'minimum': 0},
            'item_builder_hint': {'type': 'string'},
            'columns': {'type': 'integer', 'minimum': 1, 'maximum': 6},
            'kitchen_id': {'type': ['string', 'integer']},
            'dish_id': {'type': ['string', 'integer']},
            'name': {'type': 'string'},
            'description': {'type': 'string'},
            'price': {'type': ['string', 'number']},
            'image_url': {'type': 'string'},
            'available': {'type': 'boolean'},
            'show_rating': {'type': 'boolean'},
            'show_distance': {'type': 'boolean'},
            'banners': {'type': 'array', 'items': _BANNER},
            'icon': {'type': 'string', 'enum': ICONS},
        },
    }


SCREEN_SCHEMA = {
    '$schema': 'http://json-schema.org/draft-07/schema#',
    'title': 'Mealin SDUI screen spec',
    'type': 'object',
    'required': ['key', 'root'],
    'additionalProperties': False,
    'properties': {
        'key': {'type': 'string', 'minLength': 1, 'maxLength': 100},
        'version': {'type': 'integer', 'minimum': 1},
        'schema_version': {'type': 'integer', 'minimum': 1},
        'root': {'$ref': '#/definitions/node'},
    },
    'definitions': {'node': _node_schema()},
}


def validate_spec(spec):
    """Validate a screen spec.

    Returns ``(True, [])`` or ``(False, [error, ...])``.

    Beyond plain JSON Schema this also enforces the per-type field rules in
    ``_TYPE_FIELDS`` and rejects container types with no children, which JSON
    Schema alone would happily accept.
    """
    try:
        import jsonschema
    except ImportError:  # pragma: no cover - requirements.txt pins it
        return False, ['jsonschema is not installed; cannot validate specs']

    try:
        jsonschema.validate(spec, SCREEN_SCHEMA)
    except jsonschema.ValidationError as exc:
        path = '/'.join(str(p) for p in exc.absolute_path)
        return False, [f'{path or "<root>"}: {exc.message}']
    except jsonschema.SchemaError as exc:  # our own schema is malformed
        return False, [f'schema error: {exc.message}']

    errors = []
    root = spec.get('root') or {}
    _check_node(root, 'root', errors)
    return (not errors), errors


def _check_node(node, path, errors):
    if not isinstance(node, dict):
        errors.append(f'{path}: node must be an object')
        return

    ntype = node.get('type')
    allowed = _TYPE_FIELDS.get(ntype)
    if allowed is None:
        # JSON Schema already rejected unknown types; defensive only.
        errors.append(f'{path}: unknown type {ntype!r}')
        return

    # `children` is only meaningful on container types — a `text` node carrying
    # children is an authoring mistake that JSON Schema alone would accept,
    # because `children` is declared on the shared node schema.
    allowed_all = _COMMON_FIELDS | set(allowed) | {'on_tap'}
    if ntype in CONTAINER_TYPES:
        allowed_all |= {'children'}
    unknown = set(node) - allowed_all
    if unknown:
        errors.append(
            f'{path}: field(s) {sorted(unknown)} are not valid for type {ntype!r}'
        )

    if ntype in LAYOUT_TYPES and not node.get('children'):
        errors.append(f'{path}: type {ntype!r} requires a non-empty children list')

    for action_field in ('action', 'on_tap'):
        action = node.get(action_field)
        if isinstance(action, dict) and action.get('type') not in ACTION_TYPES:
            errors.append(
                f'{path}.{action_field}.type: {action.get("type")!r} is not a valid '
                f'action (allowed: {ACTION_TYPES})'
            )

    for i, child in enumerate(node.get('children') or []):
        _check_node(child, f'{path}.children[{i}]', errors)


# --------------------------------------------------------------------------
# Baked-in defaults
# --------------------------------------------------------------------------
# Every key below is seeded as an is_fallback=True row by migration 0001. They
# are deliberately plain: the point is that the app renders *something* correct
# when the database has nothing, not that these are the best possible layouts.
# The real home-feed layout stays native Flutter until SDUI is switched on.

def _home_spec():
    return {
        'key': 'customer_home',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
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
    }


DEFAULTS = {
    'customer_home': _home_spec(),
    'banners': {
        'key': 'banners',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
        # A zero-height spacer: "no opinion". The banner surface does not exist
        # yet, so its fallback must render nothing. Seeding it with real content
        # would put a hardcoded promo on every customer's home feed before an
        # admin published anything, because the fallback chain serves this row.
        # Mirrored in lib/core/sdui/default_config.dart.
        'root': {'type': 'spacer', 'height': 0},
    },
    'onboarding': {
        'key': 'onboarding',
        'version': 2,
        'schema_version': SCHEMA_VERSION,
        # Each slide is a section carrying title/subtitle plus an icon child.
        # Mirrors lib/core/sdui/default_config.dart.
        'root': {'type': 'list', 'children': [
            {
                'type': 'section', 'id': 'slide_discover',
                'title': 'Discover home kitchens near you',
                'subtitle': 'Real home cooks in your neighbourhood. Every meal is made in an actual home kitchen, not a restaurant.',
                'children': [{'type': 'text', 'text': '', 'icon': 'storefront'}],
            },
            {
                'type': 'section', 'id': 'slide_order',
                'title': 'Easy ordering',
                'subtitle': 'Order your favourite meals anytime. Add to cart, checkout, and get fast delivery to your doorstep.',
                'children': [{'type': 'text', 'text': '', 'icon': 'shopping_bag'}],
            },
            {
                'type': 'section', 'id': 'slide_delivery',
                'title': 'Fresh food, fast delivery',
                'subtitle': 'Get hot, fresh food delivered in minutes. Track your order in real-time.',
                'children': [{'type': 'text', 'text': '', 'icon': 'bolt'}],
            },
            {
                'type': 'section', 'id': 'slide_voice',
                'title': 'Just say "Hi MEAL"',
                'subtitle': 'Order hands-free with our voice assistant. Speak your order and it does the rest.',
                'children': [{'type': 'text', 'text': '', 'icon': 'mic'}],
            },
            {
                'type': 'section', 'id': 'slide_plans',
                'title': 'Meal plans that fit your week',
                'subtitle': 'Subscribe to a home cook and get fresh meals on a schedule. Skip or cancel any time.',
                'children': [{'type': 'text', 'text': '', 'icon': 'repeat'}],
            },
        ]},
    },
    'login': {
        'key': 'login',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
        'root': {'type': 'column', 'gap': 16, 'padding': {'all': 24},
                 'children': [
                     {'type': 'text', 'text': 'Welcome to MealIn', 'style': 'h1'},
                     {'type': 'text',
                      'text': 'Enter your email and we will send a one-time code.',
                      'style': 'body'},
                     {'type': 'button', 'label': 'Send OTP',
                      'variant': 'primary', 'action': {'type': 'none'}},
                 ]},
    },
    'kitchen_details': {
        'key': 'kitchen_details',
        'version': 2,
        'schema_version': SCHEMA_VERSION,
        # Section ids map to native sections in KitchenDetailsCopy. The dish
        # list itself is NOT described here: it is live provider data with no
        # JSON representation, so the server may reword headings and the empty
        # state, but never control which dishes render.
        'root': {'type': 'column', 'gap': 12, 'padding': {'all': 16},
                 'children': [
                     {'type': 'text',
                      'text': 'No dishes in this section yet.',
                      'style': 'body'},
                     {'type': 'section', 'id': 'section_menu',
                      'title': 'Menu', 'children': [
                          {'type': 'text', 'text': 'Dishes prepared today',
                           'style': 'caption'},
                      ]},
                     {'type': 'section', 'id': 'section_reviews',
                      'title': 'Reviews', 'children': [
                          {'type': 'text',
                           'text': 'What other customers said',
                           'style': 'caption'},
                      ]},
                 ]},
    },
    'customer_nav': {
        'key': 'customer_nav',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
        'root': {'type': 'list', 'children': [
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
        ]},
    },
    'chef_nav': {
        'key': 'chef_nav',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
        'root': {'type': 'list', 'children': [
            {'type': 'container', 'id': 'chef_dashboard',
             'on_tap': {'type': 'open_screen', 'value': 'dashboard'}},
        ]},
    },
    'delivery_nav': {
        'key': 'delivery_nav',
        'version': 1,
        'schema_version': SCHEMA_VERSION,
        'root': {'type': 'list', 'children': [
            {'type': 'container', 'id': 'rider_dashboard',
             'on_tap': {'type': 'open_screen', 'value': 'dashboard'}},
        ]},
    },
}


def default_for(key):
    """Return a deep copy so callers cannot mutate DEFAULTS."""
    return copy.deepcopy(DEFAULTS.get(key))