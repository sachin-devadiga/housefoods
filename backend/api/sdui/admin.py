"""Django admin CMS for SDUI.

Jazzmin is already the admin theme, so these register into the existing nav
rather than standing up a separate CMS. The important behaviour is that a spec
is validated on save (see ScreenDefinition.clean), so an unrenderable layout
cannot be published — the failure mode is a red admin form, never a broken
screen on a user's phone.
"""
import json

from django.contrib import admin, messages
from django.core.exceptions import ValidationError

from .models import (
    AppConfig, FeatureFlag, NavigationConfig, ScreenDefinition, SpecRevision,
)
from .schema import ALL_TYPES, validate_spec


class SpecRevisionInline(admin.TabularInline):
    model = SpecRevision
    extra = 0
    can_delete = False
    readonly_fields = ('version', 'spec', 'created_at', 'created_by', 'note')
    fields = readonly_fields

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(ScreenDefinition)
class ScreenDefinitionAdmin(admin.ModelAdmin):
    list_display = ('key', 'role', 'version', 'is_active', 'is_fallback',
                    'updated_at')
    list_filter = ('role', 'is_active', 'is_fallback')
    search_fields = ('key',)
    inlines = [SpecRevisionInline]
    readonly_fields = ('created_at', 'updated_at', 'published_at', 'published_by')
    actions = ('validate_all_specs', 'publish', 'rollback_to_revision')

    fieldsets = (
        (None, {'fields': ('key', 'role', 'version', 'spec')}),
        ('Publishing', {'fields': ('is_active', 'is_fallback')}),
        ('Audit', {'fields': ('created_at', 'updated_at', 'published_at',
                              'published_by'), 'classes': ('collapse',)}),
    )

    @admin.action(description='Validate specs (selected)')
    def validate_all_specs(self, request, queryset):
        """Dry-run the validator so an admin can audit a batch.

        Save already validates, so this is for bulk review rather than as a
        safety net.
        """
        bad = 0
        for screen in queryset:
            ok, errors = validate_spec(screen.spec)
            if ok:
                self.message_user(request, f'{screen.key}: OK', messages.INFO)
            else:
                bad += 1
                self.message_user(
                    request,
                    f'{screen.key}: {errors[0]}',
                    messages.ERROR,
                )
        if bad:
            self.message_user(
                request, f'{bad} screen(s) invalid.', messages.ERROR,
            )

    @admin.action(description='Publish selected (activate)')
    def publish(self, request, queryset):
        """Activate and snapshot a revision so the change can be rolled back."""
        from django.contrib.auth import get_user_model
        user = get_user_model().objects.filter(id=request.user.id).first()
        for screen in queryset:
            ok, errors = validate_spec(screen.spec)
            if not ok:
                self.message_user(
                    request,
                    f'{screen.key} not published: {errors[0]}',
                    messages.ERROR,
                )
                continue
            SpecRevision.objects.create(
                screen=screen,
                version=screen.version,
                spec=screen.spec,
                created_by=user,
                note=f'published via {request.user}',
            )
            screen.is_active = True
            screen.published_by = user
            screen.save()
        self.message_user(request, 'Publish complete.', messages.SUCCESS)

    @admin.action(description='Roll back selected to latest revision')
    def rollback_to_revision(self, request, queryset):
        """Restore the previous spec from revision history.

        The point of SDUI is being able to undo a bad config in seconds rather
        than shipping a new build, so this has to be one click.
        """
        for screen in queryset:
            revision = screen.revisions.order_by('-created_at').first()
            if revision is None:
                self.message_user(
                    request,
                    f'{screen.key}: no revision history to roll back to.',
                    messages.WARNING,
                )
                continue
            screen.spec = revision.spec
            screen.version = revision.version + 1
            screen.is_active = True
            try:
                screen.save()
            except ValidationError as exc:
                self.message_user(
                    request, f'{screen.key}: rollback invalid — {exc}',
                    messages.ERROR,
                )
                continue
            self.message_user(
                request,
                f'{screen.key}: rolled back to v{revision.version}.',
                messages.SUCCESS,
            )


@admin.register(FeatureFlag)
class FeatureFlagAdmin(admin.ModelAdmin):
    list_display = ('key', 'enabled', 'rollout_pct', 'kill_switch', 'updated_at')
    list_editable = ('enabled', 'rollout_pct')
    list_filter = ('enabled', 'kill_switch')
    search_fields = ('key', 'description')
    fieldsets = (
        (None, {'fields': ('key', 'description', 'enabled')}),
        ('Rollout', {'fields': ('rollout_pct', 'allowed_roles')}),
        ('Emergency', {'fields': ('kill_switch',), 'classes': ('collapse',)}),
    )


@admin.register(NavigationConfig)
class NavigationConfigAdmin(admin.ModelAdmin):
    list_display = ('role', 'updated_at')
    list_filter = ('role',)
    fields = ('role', 'ordered_items', 'deep_links')


@admin.register(AppConfig)
class AppConfigAdmin(admin.ModelAdmin):
    list_display = ('key', 'schema_version', 'updated_at')
    search_fields = ('key',)
    fields = ('key', 'value', 'schema_version')


@admin.register(SpecRevision)
class SpecRevisionAdmin(admin.ModelAdmin):
    """Read-only history. Created by the publish action on ScreenDefinition."""

    list_display = ('screen', 'version', 'created_at', 'created_by', 'note')
    list_filter = ('screen',)
    readonly_fields = ('screen', 'version', 'spec', 'created_at', 'created_by',
                       'note')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False