"""SDUI storage.

`ScreenDefinition` is the interesting one: its `spec` is validated on every
save, so an unrenderable layout can never reach a device. `SpecRevision` keeps
the history needed to roll back a bad publish — SDUI config is only useful if
you can undo it in seconds, not wait for a new app release.
"""
from django.core.exceptions import ValidationError
from django.db import models

from .schema import validate_spec


class Role(models.TextChoices):
    CUSTOMER = 'customer', 'Customer'
    CHEF = 'chef', 'Chef'
    DELIVERY = 'delivery_partner', 'Delivery partner'
    ALL = 'all', 'All roles'


class ScreenDefinition(models.Model):
    # `key` is deliberately NOT unique. A key can have both an active spec and a
    # fallback spec at once — that pair is the whole point of the fallback chain
    # (active -> fallback row -> baked-in default). Uniqueness is enforced on
    # (key, role, version) instead.
    key = models.CharField(
        max_length=100,
        help_text='Stable id the app requests, e.g. "customer_home".',
    )
    role = models.CharField(
        max_length=20, choices=Role.choices, default=Role.ALL,
        help_text='Which app this screen belongs to.',
    )
    version = models.PositiveIntegerField(default=1)
    spec = models.JSONField(help_text='The widget tree. Validated on save.')
    is_active = models.BooleanField(
        default=False,
        help_text='Served to the app. Drafts stay inactive.',
    )
    is_fallback = models.BooleanField(
        default=False,
        help_text='Safety net: served only when no active screen exists for '
                  'this key. Keep at least one per key.',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    published_at = models.DateTimeField(null=True, blank=True)
    published_by = models.ForeignKey(
        'auth.User', null=True, blank=True, on_delete=models.SET_NULL,
    )

    class Meta:
        db_table = 'sdui_screen_definitions'
        # Newest first so "which spec wins" is deterministic when an admin has
        # more than one active row for a key.
        ordering = ['key', '-is_active', '-version']
        constraints = [
            models.UniqueConstraint(
                fields=['key', 'role', 'version'],
                name='sdui_screen_unique_key_role_version',
            ),
        ]
        verbose_name = 'Screen definition'
        verbose_name_plural = 'Screen definitions'

    def __str__(self):
        return f'{self.key} (v{self.version})'

    def clean(self):
        super().clean()
        ok, errors = validate_spec(self.spec)
        if not ok:
            raise ValidationError(
                {'spec': 'Invalid spec: ' + '; '.join(errors[:8])}
            )

    def save(self, *args, **kwargs):
        self.full_clean(exclude=None, validate_unique=False)
        if self.is_active and self.published_at is None:
            from django.utils import timezone
            self.published_at = timezone.now()
        return super().save(*args, **kwargs)


class SpecRevision(models.Model):
    """Immutable history of a screen, so a bad publish can be rolled back."""

    screen = models.ForeignKey(
        ScreenDefinition, on_delete=models.CASCADE, related_name='revisions',
    )
    version = models.PositiveIntegerField()
    spec = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(
        'auth.User', null=True, blank=True, on_delete=models.SET_NULL,
    )
    note = models.CharField(max_length=200, blank=True)

    class Meta:
        db_table = 'sdui_spec_revisions'
        ordering = ['-version', '-created_at']

    def __str__(self):
        return f'{self.screen.key} v{self.version}'


class FeatureFlag(models.Model):
    key = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    enabled = models.BooleanField(default=False)
    rollout_pct = models.PositiveIntegerField(
        default=100,
        help_text='0-100. Above 0, only that share of devices sees the feature.',
    )
    allowed_roles = models.JSONField(
        default=list, blank=True,
        help_text='JSON list of roles, e.g. ["customer"]. Empty means all.',
    )
    kill_switch = models.BooleanField(
        default=False,
        help_text='Hard off regardless of enabled or rollout. For emergencies.',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sdui_feature_flags'
        ordering = ['key']

    def __str__(self):
        return self.key

    def clean(self):
        super().clean()
        if not 0 <= (self.rollout_pct or 0) <= 100:
            raise ValidationError({'rollout_pct': 'Must be between 0 and 100.'})
        if not isinstance(self.allowed_roles, list):
            raise ValidationError({'allowed_roles': 'Must be a JSON list.'})

    def save(self, *args, **kwargs):
        self.full_clean(exclude=None, validate_unique=False)
        return super().save(*args, **kwargs)


class NavigationConfig(models.Model):
    role = models.CharField(
        max_length=20, choices=Role.choices, unique=True,
        help_text='One config per app; use "all" only for genuinely shared nav.',
    )
    ordered_items = models.JSONField(
        default=list,
        help_text='JSON list of {"id","label","icon","enabled","order"}.',
    )
    deep_links = models.JSONField(
        default=dict, blank=True,
        help_text='JSON map of link id -> screen key.',
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sdui_navigation_configs'
        ordering = ['role']

    def __str__(self):
        return f'nav:{self.role}'


class AppConfig(models.Model):
    """Flat config values (feature copy, limits, pricing hints)."""

    key = models.CharField(max_length=100, unique=True)
    value = models.JSONField()
    schema_version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sdui_app_configs'
        ordering = ['key']

    def __str__(self):
        return self.key