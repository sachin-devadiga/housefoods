"""Refresh the seeded fallback specs after the icon contract landed.

`0002_seed_fallback_specs` inlined the specs so a migration would keep
producing the same result even if `schema.py` later changed. That is right for
reproducibility but means the seeded rows drifted when the contract gained the
`icon` field and onboarding became a list of sections.

This migration resyncs the fallback rows to match `schema.DEFAULTS`. Fallback
rows matter more than they look: the lookup chain in `api/sdui/views.py` is
active spec -> fallback row -> baked-in default, so a stale fallback is what a
client actually receives on a backend with no published screens.

Only touches rows this app seeded (is_fallback=True). Anything an admin has
published is left alone.

Depends on 0002 (the rows) and 0003 (the schema change that added
`(key, role, version)` uniqueness), because it updates rows 0002 created.
"""
from django.db import migrations


def refresh(apps, schema_editor):
    from api.sdui.schema import DEFAULTS

    ScreenDefinition = apps.get_model('sdui', 'ScreenDefinition')

    for key, spec in DEFAULTS.items():
        # Only resync our own seeds. Never overwrite admin-authored fallbacks.
        ScreenDefinition.objects.filter(
            key=key, is_fallback=True, is_active=False,
        ).update(version=spec['version'], spec=spec)


def noop(apps, schema_editor):
    """Data-only forward migration; reversing to the older rows is not
    meaningful, so this intentionally does nothing rather than writing stale
    specs back."""


class Migration(migrations.Migration):

    dependencies = [
        ('sdui', '0003_alter_screendefinition_options_and_more'),
    ]

    operations = [
        migrations.RunPython(refresh, noop),
    ]