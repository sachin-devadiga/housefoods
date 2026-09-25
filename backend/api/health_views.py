"""Safe deployment diagnostics for the GoDaddy admin investigation.

Exposes only pass/fail booleans, component names and installed versions.
Never returns tracebacks, SQL, file paths, env values or user data.
"""
import logging

import django
from django.db import connection
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

logger = logging.getLogger(__name__)


def _pkg_version(name):
    try:
        from importlib.metadata import version
        return version(name)
    except Exception:
        return 'unknown'


class AdminHealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        checks = {}

        # 1. Database connectivity (read-only SELECT 1).
        try:
            with connection.cursor() as cursor:
                cursor.execute('SELECT 1')
                cursor.fetchone()
            checks['database'] = 'ok'
        except Exception as exc:
            logger.exception('admin-health: database check failed')
            checks['database'] = f'error:{type(exc).__name__}'

        # 2. Session table present (admin login needs sessions).
        try:
            tables = set(connection.introspection.table_names())
            checks['session_table'] = (
                'ok' if 'django_session' in tables else 'missing'
            )
        except Exception as exc:
            logger.exception('admin-health: session table check failed')
            checks['session_table'] = f'error:{type(exc).__name__}'

        # 3. Admin login template compiles (catches broken template overrides).
        try:
            from django.template import engines
            engines['django'].get_template('admin/login.html')
            engines['django'].get_template('admin/index.html')
            checks['admin_templates'] = 'ok'
        except Exception as exc:
            logger.exception('admin-health: admin template check failed')
            checks['admin_templates'] = f'error:{type(exc).__name__}'

        # 4. Admin registry loads.
        try:
            from django.contrib import admin
            checks['admin_models'] = f'ok:{len(admin.site._registry)}'
        except Exception as exc:
            logger.exception('admin-health: admin registry check failed')
            checks['admin_models'] = f'error:{type(exc).__name__}'

        checks['django'] = django.get_version()
        checks['jazzmin'] = _pkg_version('django-jazzmin')

        ok = all(
            v == 'ok' or (isinstance(v, str) and v.startswith('ok:'))
            for k, v in checks.items()
            if k in ('database', 'session_table', 'admin_templates', 'admin_models')
        )
        return Response({'ok': ok, 'checks': checks})
