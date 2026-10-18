"""The production TLS posture is real, and it is deliberately off under test.

`backend/settings.py` skips its production security block when `TESTING` is
true. That guard exists because Django does not disable `SECURE_SSL_REDIRECT`
for the test runner: with `DEBUG=False` -- which is how CI and the VPS both run
-- every test-client request to `http://testserver` answers 301 before reaching
a view. 92 of 124 tests failed that way while passing locally against
`DEBUG=True`.

The risk of such a guard is that the production settings quietly rot, because
the branch that sets them never executes in any test run. So they are hoisted
into `PRODUCTION_TLS_SETTINGS` and asserted here instead.

These tests assert configuration, not behaviour: HTTP-level TLS posture is
exercised by `deploy/hostinger/deploy.sh` against the running container, where
it can be checked for real.
"""

from django.conf import settings
from django.test import SimpleTestCase


class ProductionTlsSettingsTests(SimpleTestCase):

    def test_secure_ssl_redirect_is_enabled_in_production(self):
        # Without this, a plain http request to the origin is served over
        # http. Caddy sits in front in the VPS topology, but this is the
        # in-process backstop and the deploy script relies on it being set.
        self.assertIs(settings.PRODUCTION_TLS_SETTINGS['SECURE_SSL_REDIRECT'], True)

    def test_proxy_ssl_header_is_trusted(self):
        # Caddy terminates TLS and forwards X-Forwarded-Proto. Without trusting
        # it, Django would either redirect forever or never.
        self.assertEqual(
            settings.PRODUCTION_TLS_SETTINGS['SECURE_PROXY_SSL_HEADER'],
            ('HTTP_X_FORWARDED_PROTO', 'https'),
        )

    def test_cookies_are_secure_in_production(self):
        tls = settings.PRODUCTION_TLS_SETTINGS
        self.assertIs(tls['SESSION_COOKIE_SECURE'], True)
        self.assertIs(tls['CSRF_COOKIE_SECURE'], True)

    def test_hsts_is_a_year_by_default(self):
        self.assertEqual(settings.PRODUCTION_TLS_SETTINGS['SECURE_HSTS_SECONDS'], 31536000)

    def test_all_five_keys_are_present(self):
        # A key silently dropped from the dict is a setting that stops being
        # applied in production with no error anywhere.
        self.assertEqual(
            set(settings.PRODUCTION_TLS_SETTINGS),
            {
                'SECURE_PROXY_SSL_HEADER',
                'SECURE_SSL_REDIRECT',
                'SECURE_HSTS_SECONDS',
                'SESSION_COOKIE_SECURE',
                'CSRF_COOKIE_SECURE',
            },
        )


class TestEnvironmentTests(SimpleTestCase):
    """The guard itself: these conditions must hold, or the guard stops working."""

    def test_testing_flag_is_set_during_a_test_run(self):
        self.assertIs(settings.TESTING, True)

    def test_ssl_redirect_is_not_active_during_tests(self):
        # If this ever becomes True, every test-client GET 301s and the suite
        # fails in a way that looks like application breakage.
        self.assertFalse(
            getattr(settings, 'SECURE_SSL_REDIRECT', False),
            'SECURE_SSL_REDIRECT leaked into the test environment; the '
            '`if not DEBUG and not TESTING` guard in settings.py has regressed.',
        )

    def test_testing_detection_covers_both_django_and_pytest_argv(self):
        # `_is_testing` is a function precisely so this is checkable: the
        # TESTING constant is computed once at import and cannot be re-derived.
        # If the detection regresses, CI silently starts 301ing again and
        # nothing local notices, because local runs use DEBUG=True.
        from backend.settings import _is_testing

        self.assertIs(_is_testing(['manage.py', 'test', 'api']), True)
        self.assertIs(_is_testing(['manage.py', 'test']), True)
        self.assertIs(_is_testing(['pytest']), True)
        self.assertIs(_is_testing(['pytest', '-q', 'api']), True)

        # Not a test run. Guards against an over-broad match that would disable
        # production TLS hardening on the real server.
        self.assertIs(_is_testing(['gunicorn', 'backend.wsgi:application']), False)
        self.assertIs(_is_testing(['manage.py', 'migrate']), False)
        self.assertIs(_is_testing(['manage.py', 'collectstatic']), False)
        self.assertIs(_is_testing(['manage.py', 'runserver']), False)
        self.assertIs(_is_testing([]), False)
