"""Regression suite for the routing trap this project has already hit once.

`backend/backend/urls.py` mounts `api.urls` at `api/auth/`, so every endpoint
in `api/urls.py` is served under `/api/auth/...`, NOT `/api/...`. The stale
deploy docs mixed the two, which is exactly the kind of bug that looks fine
until something 404s in production.

These tests assert two things:

1. **Routes resolve** under `/api/auth/` — a 200, or a deliberate 4xx that means
   "the route exists and the request was refused", never a routing 404.
2. **The bare `/api/` prefix does NOT resolve**, so a future edit that moves a
   route out from under `/api/auth/` gets caught.

Public endpoints (no auth) are asserted for a real 200 where possible, because
those are the ones an outage is most visible through.
"""
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from api.models import Address, UserProfile


def _mkuser(email, role):
    return UserProfile.objects.create(
        user=User.objects.create_user(username=email, email=email, password='x'),
        email=email, name=email.split('@')[0], role=role,
    )


class PublicEndpointSmokeTests(TestCase):
    """Endpoints reachable without a token. A 500 here takes the app down."""

    def setUp(self):
        self.client = APIClient()

    def test_admin_health_is_ok(self):
        response = self.client.get('/api/auth/admin-health/')
        self.assertEqual(response.status_code, 200, response.content)
        self.assertTrue(response.json()['ok'])

    def test_app_version_returns_a_payload(self):
        response = self.client.get('/api/auth/app-version/')
        self.assertEqual(response.status_code, 200, response.content)
        for key in ('latestVersion', 'minVersion'):
            self.assertIn(key, response.json())

    def test_kitchen_categories_returns_a_page(self):
        # DRF pagination is global here, so list endpoints answer with the
        # {count, next, previous, results} envelope, not a bare array. Asserted
        # as an envelope deliberately: if pagination is ever switched off, this
        # is the test that notices and forces the client contract to be updated.
        response = self.client.get('/api/auth/kitchen-categories/')
        self.assertEqual(response.status_code, 200, response.content)
        body = response.json()
        for key in ('count', 'results'):
            self.assertIn(key, body)
        self.assertIsInstance(body['results'], list)

    def test_banners_endpoint_is_public(self):
        # Customer-facing promos render on the login/onboarding surfaces, before
        # a token exists. If this ever starts requiring auth, new users see an
        # empty home screen.
        response = self.client.get('/api/auth/banners/')
        self.assertEqual(response.status_code, 200, response.content)

    def test_sdui_bootstrap_is_public(self):
        # SDUI must render before login, so this must never require a token.
        response = self.client.get('/api/auth/config/bootstrap/')
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()['schema_version'], 1)

    def test_sdui_banners_screen_is_public(self):
        response = self.client.get('/api/auth/config/screens/banners/')
        self.assertEqual(response.status_code, 200, response.content)

    def test_sdui_manifest_is_public(self):
        response = self.client.get('/api/auth/config/manifest/')
        self.assertEqual(response.status_code, 200, response.content)


class RoutePrefixTests(TestCase):
    """The bare `/api/` prefix must not resolve anything."""

    BARE_PREFIX_PATHS = [
        '/api/admin-health/',
        '/api/app-version/',
        '/api/kitchen-categories/',
        '/api/kitchens/',
        '/api/config/bootstrap/',
        '/api/config/screens/banners/',
        '/api/subscriptions/plans/',
        '/api/banners/',
    ]

    def test_bare_api_prefix_is_all_404(self):
        for path in self.BARE_PREFIX_PATHS:
            with self.subTest(path=path):
                response = APIClient().get(path)
                self.assertEqual(
                    response.status_code, 404,
                    f'{path} resolved, but api.urls is mounted at api/auth/ — '
                    f'something moved a route out from under the prefix.',
                )


class AuthenticatedRouteExistsTests(TestCase):
    """Protected endpoints must be 401/403, never 404.

    A 404 here means the route is missing; 401/403 means the route exists and
    correctly refused us. Confusing the two is how a missing endpoint ships.
    """

    PROTECTED_PATHS = [
        '/api/auth/profile/',
        '/api/auth/logout/',
        '/api/auth/orders/',
        '/api/auth/cart/',
        '/api/auth/wallet/',
        '/api/auth/notifications/',
        '/api/auth/chat/messages/',
        '/api/auth/support-tickets/',
        '/api/auth/admin/dashboard/',
        '/api/auth/delivery/available/',
        '/api/auth/delivery/earnings/',
        '/api/auth/map/route/',
        '/api/auth/ai/chat/',
        '/api/auth/voice/stt/',
        '/api/auth/kitchens/',
        '/api/auth/subscriptions/plans/',
        '/api/auth/subscriptions/mine/',
        '/api/auth/subscriptions/chef-plans/',
        '/api/auth/subscriptions/chef-subscribers/',
        '/api/auth/subscriptions/plan-cadences/',
    ]

    def test_token_refresh_is_post_only(self):
        # 405 rather than 404: the route exists, a GET just isn't a verb it
        # accepts. Listed separately so a GET-probe does not read as "missing".
        response = APIClient().get('/api/auth/token/refresh/')
        self.assertEqual(response.status_code, 405)

    def test_all_protected_routes_exist(self):
        for path in self.PROTECTED_PATHS:
            with self.subTest(path=path):
                response = APIClient().get(path)
                self.assertIn(
                    response.status_code, (401, 403),
                    f'{path} returned {response.status_code}; expected 401/403 '
                    f'(route exists but is protected). 404 means no route.',
                )

    def test_authenticated_chef_can_reach_plan_cadences(self):
        chef = _mkuser('chef-route@p.dev', 'chef')
        client = APIClient()
        client.force_authenticate(user=chef.user)
        response = client.get('/api/auth/subscriptions/plan-cadences/')
        self.assertEqual(response.status_code, 200, response.content)

    def test_authenticated_customer_can_list_kitchens(self):
        # NOTE the contract inconsistency, asserted as-is on purpose:
        # `kitchen-categories/` is a generics.ListAPIView so it inherits the
        # global PageNumberPagination and answers with a {count, results}
        # envelope, while `kitchens/` is a hand-written APIView that answers
        # with a bare array. Both are consumed by the shipped Flutter client,
        # so neither was changed here to "fix" the inconsistency -- that would
        # be a breaking API change needing a client bump. This test exists so
        # that if either side is ever migrated, the change is deliberate.
        customer = _mkuser('cust-kitchens@p.dev', 'customer')
        client = APIClient()
        client.force_authenticate(user=customer.user)
        response = client.get('/api/auth/kitchens/')
        self.assertEqual(response.status_code, 200, response.content)
        self.assertIsInstance(response.json(), list)

    def test_kitchen_categories_uses_the_pagination_envelope(self):
        # The other half of the pair above, asserted separately so the two
        # shapes are both pinned down.
        response = APIClient().get('/api/auth/kitchen-categories/')
        body = response.json()
        self.assertIn('results', body)
        self.assertIn('count', body)
        self.assertIsInstance(body['results'], list)

    def test_subscription_plans_require_a_delivery_address(self):
        # Browsing plans is gated on having an address: quote/availability is
        # computed per delivery location. 400 (not 401/403) is correct here --
        # the caller is authenticated, just not yet eligible.
        customer = _mkuser('cust-plans@p.dev', 'customer')
        client = APIClient()
        client.force_authenticate(user=customer.user)
        response = client.get('/api/auth/subscriptions/plans/')
        self.assertEqual(response.status_code, 400, response.content)
        self.assertIn('address', response.json()['error'].lower())

    def test_subscription_plans_list_once_an_address_exists(self):
        customer = _mkuser('cust-plans2@p.dev', 'customer')
        Address.objects.create(
            user=customer, address_line1='1 Test Street', city='Bengaluru',
            state='Karnataka', pincode='560001', is_default=True,
        )
        client = APIClient()
        client.force_authenticate(user=customer.user)
        response = client.get('/api/auth/subscriptions/plans/')
        self.assertEqual(response.status_code, 200, response.content)
        # A third contract shape: paginated envelope.
        body = response.json()
        self.assertIn('results', body, f'expected a page envelope, got {body}')
        self.assertIsInstance(body['results'], list)

    def test_authenticated_customer_can_reach_profile(self):
        customer = _mkuser('cust-route@p.dev', 'customer')
        client = APIClient()
        client.force_authenticate(user=customer.user)
        response = client.get('/api/auth/profile/')
        self.assertEqual(response.status_code, 200, response.content)

    def test_chef_plans_returns_403_for_a_customer(self):
        # Confirms the route is both present AND scoped, not just present.
        customer = _mkuser('cust-plan@p.dev', 'customer')
        client = APIClient()
        client.force_authenticate(user=customer.user)
        response = client.get('/api/auth/subscriptions/chef-plans/')
        self.assertEqual(response.status_code, 403, response.content)


class AdminDjangoRoutesTests(TestCase):
    """The Django admin must load — an SDUI config typo there locks everyone out."""

    def test_admin_login_page_renders(self):
        response = self.client.get('/admin/login/')
        self.assertEqual(response.status_code, 200)

    def test_admin_index_redirects_when_anonymous(self):
        response = self.client.get('/admin/')
        self.assertIn(response.status_code, (302, 200))

    def test_sdui_admin_pages_load_for_superuser(self):
        admin = User.objects.create_superuser(
            username='root@p.dev', email='root@p.dev', password='x',
        )
        UserProfile.objects.create(
            user=admin, email='root@p.dev', name='root', role='admin',
        )
        self.client.force_login(admin)
        for path in (
            '/admin/sdui/screendefinition/',
            '/admin/sdui/featureflag/',
            '/admin/sdui/navigationconfig/',
            '/admin/sdui/appconfig/',
        ):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)

    def test_existing_custom_admin_pages_still_load(self):
        admin = User.objects.create_superuser(
            username='root2@p.dev', email='root2@p.dev', password='x',
        )
        UserProfile.objects.create(
            user=admin, email='root2@p.dev', name='root2', role='admin',
        )
        self.client.force_login(admin)
        for path in (
            '/admin/dashboard/',
            '/admin/reports/kitchens/',
            '/admin/reports/delivery-partners/',
        ):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)


class MediaServingTests(TestCase):
    """MEDIA_ROOT is served by Django in production.

    `backend/urls.py` adds a `re_path` for media only when DEBUG is False,
    because `static()` returns an empty list in production. Kitchen photos and
    dish images 404 if that wiring regresses, and the symptom looks like "the
    image is broken" rather than a routing fault.
    """

    def test_media_url_is_wired(self):
        from django.conf import settings
        from django.urls import get_resolver
        patterns = get_resolver().url_patterns
        flat = []

        def walk(p):
            for entry in p:
                flat.append(entry)
                if hasattr(entry, 'url_patterns'):
                    walk(entry.url_patterns)

        walk(patterns)
        media_routes = [
            str(e.pattern) for e in flat
            if 'media' in str(e.pattern)
        ]
        self.assertTrue(
            media_routes,
            'no media route found — uploaded images would 404 in production',
        )