"""SDUI backend tests.

The cases that matter most are the failure paths. A spec system is only safe if
a bad config cannot reach a device, and if an empty database still renders. Both
are asserted here rather than assumed.
"""
from django.core.exceptions import ValidationError
from django.test import TestCase
from django.urls import reverse

from api.models import AdminSetting
from api.sdui.models import FeatureFlag, NavigationConfig, ScreenDefinition
from api.sdui.schema import DEFAULTS, default_for, validate_spec


class SpecValidationTests(TestCase):
    """The validator is the gate between an admin's typo and a broken screen."""

    def test_default_specs_are_valid(self):
        # If a baked-in default ever fails validation, an empty database would
        # hand the client a spec it cannot render.
        for key, spec in DEFAULTS.items():
            ok, errors = validate_spec(spec)
            self.assertTrue(ok, f'{key} is invalid: {errors}')

    def test_minimal_valid_spec(self):
        ok, _ = validate_spec({
            'key': 'x', 'root': {'type': 'column', 'children': [
                {'type': 'text', 'text': 'hi'},
            ]},
        })
        self.assertTrue(ok)

    def test_missing_type_rejected(self):
        ok, errors = validate_spec({'key': 'x', 'root': {'children': []}})
        self.assertFalse(ok)
        self.assertTrue(errors)

    def test_unknown_type_rejected(self):
        # A typo like 'banner_carosel' must fail loudly, not render nothing.
        ok, _ = validate_spec({'key': 'x', 'root': {'type': 'banar_carosel'}})
        self.assertFalse(ok)

    def test_unknown_field_for_type_rejected(self):
        ok, errors = validate_spec({
            'key': 'x',
            'root': {'type': 'text', 'children': []},
        })
        self.assertFalse(ok)
        self.assertTrue(any('children' in e for e in errors))

    def test_bad_action_type_rejected(self):
        ok, _ = validate_spec({
            'key': 'x',
            'root': {'type': 'column', 'children': [
                {'type': 'container',
                 'on_tap': {'type': 'launch_missiles', 'value': 'y'}},
            ]},
        })
        self.assertFalse(ok)

    def test_container_requires_children(self):
        ok, _ = validate_spec({'key': 'x', 'root': {'type': 'column'}})
        self.assertFalse(ok)

    def test_negative_padding_rejected(self):
        ok, _ = validate_spec({
            'key': 'x',
            'root': {'type': 'column', 'padding': {'all': -4}, 'children': [
                {'type': 'text', 'text': 'a'},
            ]},
        })
        self.assertFalse(ok)


class PublishGateTests(TestCase):
    """A bad spec must be impossible to save, not merely discouraged."""

    def test_invalid_spec_cannot_be_saved(self):
        with self.assertRaises(ValidationError):
            ScreenDefinition.objects.create(
                key='bad',
                spec={'key': 'bad', 'root': {'type': 'nonsense'}},
            )

    def test_draft_is_not_stamped_as_published(self):
        # published_at means "this spec is live for clients". A draft has not
        # been published, so it must not carry a timestamp.
        screen = ScreenDefinition.objects.create(
            key='draft', spec=default_for('banners'), is_active=False,
        )
        self.assertIsNone(screen.published_at)

    def test_active_spec_is_stamped_as_published(self):
        screen = ScreenDefinition.objects.create(
            key='live', spec=default_for('banners'), is_active=True,
        )
        self.assertIsNotNone(screen.published_at)


class BootstrapEndpointTests(TestCase):
    """The app reads this before it can render anything."""

    def test_returns_200_and_expected_shape(self):
        response = self.client.get(reverse('sdui-bootstrap'))
        self.assertEqual(response.status_code, 200)
        for key in ('schema_version', 'maintenance', 'min_app_version',
                    'force_update', 'feature_flags', 'navigation'):
            self.assertIn(key, response.json())

    def test_reads_maintenance_from_admin_setting(self):
        AdminSetting.objects.update_or_create(
            key='maintenance_mode',
            defaults={'value': 'true'},
        )
        AdminSetting.objects.update_or_create(
            key='maintenance_message',
            defaults={'value': 'Back in 10 minutes'},
        )
        data = self.client.get(reverse('sdui-bootstrap')).json()
        self.assertTrue(data['maintenance']['enabled'])
        self.assertEqual(data['maintenance']['message'], 'Back in 10 minutes')

    def test_maintenance_false_by_default(self):
        data = self.client.get(reverse('sdui-bootstrap')).json()
        self.assertFalse(data['maintenance']['enabled'])

    def test_includes_feature_flags(self):
        FeatureFlag.objects.create(key='new_cart', enabled=True, rollout_pct=50)
        data = self.client.get(reverse('sdui-bootstrap')).json()
        flag = data['feature_flags']['new_cart']
        self.assertTrue(flag['enabled'])
        self.assertEqual(flag['rollout_pct'], 50)

    def test_includes_navigation(self):
        NavigationConfig.objects.create(
            role='customer',
            ordered_items=[{'id': 'home', 'enabled': True, 'order': 0}],
        )
        data = self.client.get(reverse('sdui-bootstrap')).json()
        self.assertEqual(data['navigation']['customer']['items'][0]['id'],
                         'home')

    def test_etag_then_304(self):
        url = reverse('sdui-bootstrap')
        first = self.client.get(url)
        etag = first['ETag']
        second = self.client.get(url, HTTP_IF_NONE_MATCH=etag)
        self.assertEqual(second.status_code, 304)

    def test_no_auth_required(self):
        # The app must render before login, so this must never 401.
        self.assertEqual(
            self.client.get(reverse('sdui-bootstrap')).status_code, 200,
        )


class ScreenEndpointTests(TestCase):
    """active spec -> fallback row -> baked-in default. Never a 500."""

    def test_returns_seeded_fallback(self):
        # Migration 0002 seeds all DEFAULTS keys as fallbacks.
        response = self.client.get(reverse('sdui-screen', args=['banners']))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['key'], 'banners')
        self.assertIn('root', data)

    def test_unknown_key_is_404_not_500(self):
        response = self.client.get(
            reverse('sdui-screen', args=['does_not_exist'])
        )
        self.assertEqual(response.status_code, 404)

    def test_falls_back_to_baked_in_default_when_table_empty(self):
        ScreenDefinition.objects.all().delete()
        response = self.client.get(reverse('sdui-screen', args=['customer_home']))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['key'], 'customer_home')

    def test_active_spec_beats_fallback(self):
        ScreenDefinition.objects.all().delete()
        ScreenDefinition.objects.create(
            key='customer_home', role='all', version=1,
            is_fallback=True, is_active=False,
            spec=default_for('customer_home'),
        )
        live = default_for('customer_home')
        live['root']['children'] = [{'type': 'text', 'text': 'LIVE'}]
        ScreenDefinition.objects.create(
            key='customer_home', role='all', version=2,
            is_fallback=False, is_active=True, spec=live,
        )
        root = self.client.get(
            reverse('sdui-screen', args=['customer_home'])
        ).json()['root']
        self.assertEqual(root['children'][0]['text'], 'LIVE')

    def test_corrupt_row_does_not_500(self):
        # Bypass validation to simulate a row damaged outside the admin.
        ScreenDefinition.objects.all().delete()
        screen = ScreenDefinition(key='customer_home', spec={'garbage': True})
        ScreenDefinition.objects.bulk_create([screen])
        response = self.client.get(
            reverse('sdui-screen', args=['customer_home'])
        )
        # Corrupt row is skipped and the baked-in default answers instead.
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['key'], 'customer_home')


class ManifestEndpointTests(TestCase):
    def test_returns_200_and_screens_map(self):
        response = self.client.get(reverse('sdui-manifest'))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('schema_version', data)
        self.assertIsInstance(data['screens'], dict)

    def test_filters_by_role(self):
        ScreenDefinition.objects.all().delete()
        ScreenDefinition.objects.create(
            key='customer_only', role='customer', is_active=True,
            spec=default_for('banners'),
        )
        ScreenDefinition.objects.create(
            key='chef_only', role='chef', is_active=True,
            spec=default_for('banners'),
        )
        data = self.client.get(
            reverse('sdui-manifest'), {'role': 'customer'}
        ).json()
        self.assertIn('customer_only', data['screens'])
        self.assertNotIn('chef_only', data['screens'])

    def test_manifest_never_500_when_empty(self):
        ScreenDefinition.objects.all().delete()
        response = self.client.get(reverse('sdui-manifest'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['screens'], {})


class RoutingTests(TestCase):
    """Guards the prefix trap that has already bitten this project once."""

    def test_config_endpoints_live_under_api_auth(self):
        # api.urls is included at 'api/auth/' in backend/urls.py, so these must
        # resolve there and NOT under bare /api/.
        self.assertEqual(self.client.get('/api/auth/config/bootstrap/')
                         .status_code, 200)
        self.assertEqual(self.client.get('/api/auth/config/manifest/')
                         .status_code, 200)

    def test_bare_api_config_does_not_resolve(self):
        self.assertEqual(self.client.get('/api/config/bootstrap/').status_code,
                         404)