"""Public read API for SDUI config.

Two invariants, both load-bearing:

1. **These endpoints never 500.** A missing key, an empty table, or a corrupt
   row must all produce a renderable response. The client treats a failed fetch
   as "keep what you had", but a 500 is noisier and hides real faults.
2. **No auth.** The app must render before login, so an unauthenticated request
   gets the same payload. Everything served here is presentation config that is
   already visible in the app bundle.

`bootstrap` reuses the pre-existing `AdminSetting` table for maintenance and
force-update values rather than inventing a second store, so an admin keeps one
place to flip a kill switch.
"""
import hashlib
import json
import logging

from django.core.cache import cache
from django.db.models import Q
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from api.models import AdminSetting

from .models import (
    AppConfig, FeatureFlag, NavigationConfig, Role, ScreenDefinition,
)
from .schema import SCHEMA_VERSION, default_for

logger = logging.getLogger(__name__)

# Keys borrowed from the existing AdminSetting mechanism.
MAINTENANCE_KEY = 'maintenance_mode'
MAINTENANCE_MSG_KEY = 'maintenance_message'
MIN_VERSION_KEY = 'min_app_version'
FORCE_UPDATE_KEY = 'force_update'
LATEST_VERSION_KEY = 'latest_version'

_SETTING_DEFAULTS = {
    MAINTENANCE_KEY: 'false',
    MAINTENANCE_MSG_KEY: (
        "We're performing a scheduled upgrade. Please check back shortly."
    ),
    MIN_VERSION_KEY: '1.0.0',
    FORCE_UPDATE_KEY: 'false',
    LATEST_VERSION_KEY: '1.0.0',
}

# Payloads never contain secrets, so a short shared cache is safe. 30s keeps
# config changes feeling immediate without turning this into a hot path.
CACHE_SECONDS = 30


def _setting(key):
    """Read an AdminSetting, creating it with its default on first access.

    Mirrors the get-or-create pattern in api/views.py so an admin sees the key
    in the Django admin without needing a migration.
    """
    obj, _ = AdminSetting.objects.get_or_create(
        key=key, defaults={'value': _SETTING_DEFAULTS[key]},
    )
    return obj.value


def _as_bool(value):
    return str(value).strip().lower() in ('true', '1', 'yes', 'on')


def _etag(payload):
    blob = json.dumps(payload, sort_keys=True, default=str).encode()
    return hashlib.md5(blob).hexdigest()


def _not_modified(request, payload):
    """Return a 304 Response when the client's ETag still matches."""
    etag = _etag(payload)
    if request.headers.get('If-None-Match', '').strip('"') == etag:
        response = Response(status=304)
    else:
        response = Response(payload)
    response['ETag'] = f'"{etag}"'
    response['Cache-Control'] = f'public, max-age={CACHE_SECONDS}'
    return response


def _active_screen(key):
    """Active spec for a key, else the fallback spec, else the baked-in default.

    This is the chain that makes an empty or half-populated database harmless.
    """
    try:
        screen = ScreenDefinition.objects.filter(key=key, is_active=True).first()
        if screen is not None:
            return {
                'key': screen.key,
                'version': screen.version,
                'schema_version': SCHEMA_VERSION,
                'root': screen.spec.get('root'),
            }
        fallback = (
            ScreenDefinition.objects.filter(key=key, is_fallback=True)
            .order_by('-version')
            .first()
        )
        if fallback is not None:
            return {
                'key': fallback.key,
                'version': fallback.version,
                'schema_version': SCHEMA_VERSION,
                'root': fallback.spec.get('root'),
            }
    except Exception:
        logger.exception('sdui: screen lookup failed for key=%s', key)

    spec = default_for(key)
    if spec is None:
        return None
    return {
        'key': spec['key'],
        'version': spec['version'],
        'schema_version': SCHEMA_VERSION,
        'root': spec['root'],
    }


class BootstrapView(APIView):
    """Everything the app needs before it can render anything.

    Deliberately small: maintenance state, the force-update floor, feature
    flags and nav order. Screen specs come from the screen/manifest endpoints
    so that changing a layout does not invalidate the flag payload.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        try:
            maintenance = _as_bool(_setting(MAINTENANCE_KEY))
            flags = {
                f.key: {
                    'enabled': bool(f.enabled),
                    'rollout_pct': int(f.rollout_pct or 0),
                    'allowed_roles': f.allowed_roles or [],
                    'kill_switch': bool(f.kill_switch),
                }
                for f in FeatureFlag.objects.all()
            }
            navigation = {
                n.role: {
                    'items': n.ordered_items or [],
                    'deep_links': n.deep_links or {},
                }
                for n in NavigationConfig.objects.all()
            }
            config = {c.key: c.value for c in AppConfig.objects.all()}

            payload = {
                'schema_version': SCHEMA_VERSION,
                'maintenance': {
                    'enabled': maintenance,
                    'message': _setting(MAINTENANCE_MSG_KEY),
                },
                'min_app_version': _setting(MIN_VERSION_KEY),
                'latest_app_version': _setting(LATEST_VERSION_KEY),
                'force_update': _as_bool(_setting(FORCE_UPDATE_KEY)),
                'feature_flags': flags,
                'navigation': navigation,
                'config': config,
            }
        except Exception:
            # A config endpoint that raises would leave the client on cached
            # values with no signal. Report it as "nothing new" instead.
            logger.exception('sdui: bootstrap failed')
            payload = {
                'schema_version': SCHEMA_VERSION,
                'maintenance': {'enabled': False, 'message': ''},
                'min_app_version': '1.0.0',
                'latest_app_version': '1.0.0',
                'force_update': False,
                'feature_flags': {},
                'navigation': {},
                'config': {},
            }
        return _not_modified(request, payload)


class ScreenView(APIView):
    """One screen spec by key."""

    permission_classes = [AllowAny]

    def get(self, request, key):
        payload = _active_screen(key)
        if payload is None:
            # An unknown key is a client bug, but 404 is still a correct answer
            # and far more debuggable than an empty spec.
            return Response({'error': f'unknown screen key: {key}'}, status=404)
        return _not_modified(request, payload)


class ManifestView(APIView):
    """All active screens for a role, in one round trip."""

    permission_classes = [AllowAny]

    def get(self, request):
        role = request.query_params.get('role', 'all')
        try:
            screens = ScreenDefinition.objects.filter(
                Q(role=role) | Q(role=Role.ALL), is_active=True,
            )
            out = {}
            for screen in screens:
                out[screen.key] = {
                    'version': screen.version,
                    'root': screen.spec.get('root'),
                }
            payload = {'schema_version': SCHEMA_VERSION, 'screens': out}
        except Exception:
            logger.exception('sdui: manifest failed')
            payload = {'schema_version': SCHEMA_VERSION, 'screens': {}}
        return _not_modified(request, payload)