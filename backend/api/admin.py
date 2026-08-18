from django.contrib import admin
from django.http import HttpResponse
from django.forms.models import BaseInlineFormSet
from django.utils.encoding import force_str
from django.utils.html import format_html
from django.utils import timezone
from django.db.models import Count, Sum, Q
from .models import (
    UserProfile, Address, Kitchen, KitchenImage, KitchenCategory,
    MenuCategory, MenuItem, SubscriptionPlan, DailyMenu, Order,
    DeliveryLog, Payment, WalletTransaction, Review, Coupon,
    SupportTicket, Banner, AdminSetting, PayoutRequest,
    DeliveryDocument,
)


STATUS_COLORS = {
    'pending': 'warning', 'verified': 'success', 'rejected': 'danger',
    'open': 'info', 'in_progress': 'info', 'delivered': 'success',
    'cancelled': 'danger', 'approved': 'success', 'active': 'success',
    'inactive': 'secondary', True: 'success', False: 'secondary',
}


def badge(value, text=None):
    color = STATUS_COLORS.get(value, 'secondary') if isinstance(value, str) else STATUS_COLORS.get(value, 'secondary')
    label = text or str(value).replace('_', ' ').title()
    return format_html('<span class="badge badge-{}">{}</span>', color, label)


def veg_badge(is_veg):
    color = 'success' if is_veg else 'danger'
    label = 'Veg' if is_veg else 'Non-Veg'
    return format_html('<span class="badge badge-{}">{}</span>', color, label)


class BulkActionsAdmin(admin.ModelAdmin):
    """Provides a useful action menu on every Mealin admin list page."""

    actions = ['export_selected_records']

    @admin.action(description='Export selected records as CSV')
    def export_selected_records(self, request, queryset):
        """Download only concrete model fields, so relations export as their IDs."""
        model = self.model
        fields = list(model._meta.concrete_fields)
        response = HttpResponse(content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = (
            f'attachment; filename="{model._meta.model_name}-export.csv"'
        )
        response.write('\ufeff')  # Helps Excel detect UTF-8.

        import csv
        writer = csv.writer(response)
        writer.writerow([field.verbose_name for field in fields])
        for obj in queryset:
            writer.writerow([force_str(getattr(obj, field.attname)) for field in fields])
        return response


class KitchenImageInline(admin.TabularInline):
    model = KitchenImage
    extra = 1
    fields = ['image_url', 'is_primary']


class MenuItemFormSet(BaseInlineFormSet):
    def save_new(self, form, commit=True):
        obj = form.save(commit=False)
        obj.kitchen = self.instance.kitchen
        if commit:
            obj.save()
        return obj

class MenuItemInline(admin.TabularInline):
    model = MenuItem
    formset = MenuItemFormSet
    extra = 1
    fields = ['name', 'price', 'is_available', 'is_veg']
    show_change_link = True


@admin.register(UserProfile)
class UserProfileAdmin(BulkActionsAdmin):
    list_display = ['email', 'name', 'role_badge', 'phone', 'wallet_balance', 'is_active', 'is_verified', 'is_available', 'created_at']
    list_filter = ['role', 'is_active', 'is_verified', 'is_available']
    search_fields = ['email', 'name', 'phone', 'uid']
    readonly_fields = ['uid', 'created_at', 'updated_at']
    fieldsets = [
        ('Account Info', {'fields': ['email', 'name', 'phone', 'role']}),
        ('Status', {'fields': ['is_active', 'is_verified', 'is_available', 'fcm_token']}),
        ('Wallet', {'fields': ['wallet_balance']}),
        ('Meta', {'fields': ['uid', 'avatar_url', 'favorite_kitchen_ids', 'created_at', 'updated_at']}),
    ]

    def role_badge(self, obj):
        colors = {'customer': 'info', 'chef': 'primary', 'delivery_partner': 'warning', 'admin': 'danger'}
        role = obj.role or 'customer'
        return format_html('<span class="badge badge-{}">{}</span>', colors.get(role, 'secondary'), role.replace('_', ' ').title())
    role_badge.short_description = 'Role'


@admin.register(Address)
class AddressAdmin(BulkActionsAdmin):
    list_display = ['user', 'label', 'address_line1', 'city', 'state', 'is_default']
    list_filter = ['city', 'state', 'is_default']
    search_fields = ['user__email', 'city', 'address_line1']


@admin.register(KitchenCategory)
class KitchenCategoryAdmin(BulkActionsAdmin):
    list_display = ['name', 'icon', 'active_badge', 'sort_order']
    list_editable = ['sort_order']
    list_filter = ['is_active']
    search_fields = ['name']

    def active_badge(self, obj):
        return badge(obj.is_active, 'Active' if obj.is_active else 'Inactive')
    active_badge.short_description = 'Status'


@admin.register(Kitchen)
class KitchenAdmin(BulkActionsAdmin):
    list_display = ['name', 'chef', 'status_badge', 'open_badge', 'rating', 'total_ratings', 'created_at']
    list_filter = ['status', 'is_open', 'categories']
    search_fields = ['name', 'chef__email', 'chef__name']
    inlines = [KitchenImageInline]
    readonly_fields = ['created_at', 'updated_at', 'rating', 'total_ratings']
    fieldsets = [
        ('Basic Info', {'fields': ['chef', 'name', 'description', 'phone']}),
        ('Status', {'fields': ['status', 'is_open']}),
        ('Location', {'fields': ['address', 'latitude', 'longitude']}),
        ('Categories', {'fields': ['categories', 'categories_list']}),
        ('Media', {'fields': ['gallery_images']}),
        ('Ratings', {'fields': ['rating', 'total_ratings']}),
        ('Timestamps', {'fields': ['created_at', 'updated_at']}),
    ]

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'

    def open_badge(self, obj):
        return badge(obj.is_open, 'Open' if obj.is_open else 'Closed')
    open_badge.short_description = 'Open'


@admin.register(KitchenImage)
class KitchenImageAdmin(BulkActionsAdmin):
    list_display = ['kitchen', 'image_url', 'is_primary']
    list_filter = ['is_primary', 'kitchen']


@admin.register(MenuCategory)
class MenuCategoryAdmin(BulkActionsAdmin):
    list_display = ['name', 'kitchen', 'sort_order', 'items_count']
    list_filter = ['kitchen']
    search_fields = ['name', 'kitchen__name']
    inlines = [MenuItemInline]

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(items_count=Count('items'))

    def items_count(self, obj):
        return obj.items_count
    items_count.short_description = 'Items'


@admin.register(MenuItem)
class MenuItemAdmin(BulkActionsAdmin):
    list_display = ['name', 'kitchen', 'category', 'price', 'is_available', 'veg_badge', 'preparation_time']
    list_filter = ['is_available', 'is_veg', 'kitchen']
    search_fields = ['name', 'kitchen__name', 'category__name']
    list_editable = ['price', 'is_available', 'preparation_time']
    readonly_fields = ['created_at', 'updated_at']

    def veg_badge(self, obj):
        return veg_badge(obj.is_veg)
    veg_badge.short_description = 'Type'


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(BulkActionsAdmin):
    list_display = ['name', 'kitchen', 'price', 'duration_days', 'meals_per_day', 'active_badge']
    list_filter = ['is_active', 'kitchen']
    search_fields = ['name', 'kitchen__name']
    list_editable = ['price', 'duration_days', 'meals_per_day']

    def active_badge(self, obj):
        return badge(obj.is_active, 'Active' if obj.is_active else 'Inactive')
    active_badge.short_description = 'Active'


@admin.register(DailyMenu)
class DailyMenuAdmin(BulkActionsAdmin):
    list_display = ['kitchen', 'date', 'active_badge', 'created_at']
    list_filter = ['is_active', 'date', 'kitchen']
    search_fields = ['kitchen__name']
    date_hierarchy = 'date'

    def active_badge(self, obj):
        return badge(obj.is_active, 'Active' if obj.is_active else 'Inactive')
    active_badge.short_description = 'Active'


@admin.register(Order)
class OrderAdmin(BulkActionsAdmin):
    list_display = ['id', 'customer', 'kitchen', 'amount', 'status_badge', 'delivery_status_badge', 'delivery_partner', 'created_at']
    list_filter = ['status', 'delivery_status', 'kitchen']
    search_fields = ['customer__email', 'customer__name', 'kitchen__name', 'id']
    readonly_fields = ['id', 'created_at', 'updated_at']
    date_hierarchy = 'created_at'
    fieldsets = [
        ('Order Info', {'fields': ['id', 'customer', 'kitchen', 'amount', 'delivery_fee']}),
        ('Plan', {'fields': ['plan', 'plan_name']}),
        ('Status', {'fields': ['status', 'delivery_status']}),
        ('Delivery', {'fields': ['delivery_address', 'delivery_partner', 'delivery_slot_id', 'meal_type']}),
        ('Schedule', {'fields': ['start_date', 'end_date', 'assigned_at', 'picked_up_at', 'delivered_at']}),
        ('Payment', {'fields': ['payment_id']}),
        ('Flags', {'fields': ['is_paused']}),
        ('Timestamps', {'fields': ['created_at', 'updated_at']}),
    ]

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'

    def delivery_status_badge(self, obj):
        return badge(obj.delivery_status)
    delivery_status_badge.short_description = 'Delivery'


@admin.register(DeliveryLog)
class DeliveryLogAdmin(BulkActionsAdmin):
    list_display = ['order', 'date', 'status_badge', 'rating', 'refund_amount', 'delivered_by']
    list_filter = ['status', 'date']
    search_fields = ['order__id', 'delivered_by__email']
    date_hierarchy = 'date'
    readonly_fields = ['created_at']

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'


@admin.register(Payment)
class PaymentAdmin(BulkActionsAdmin):
    list_display = ['payment_id', 'order', 'user', 'amount', 'status_badge', 'method', 'created_at']
    list_filter = ['status', 'method']
    search_fields = ['payment_id', 'user__email', 'order__id']
    readonly_fields = ['created_at']

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'


@admin.register(WalletTransaction)
class WalletTransactionAdmin(BulkActionsAdmin):
    list_display = ['user', 'amount', 'type', 'category', 'description', 'created_at']
    list_filter = ['type', 'category']
    search_fields = ['user__email', 'description']
    readonly_fields = ['created_at']


@admin.register(Review)
class ReviewAdmin(BulkActionsAdmin):
    list_display = ['kitchen', 'user', 'stars', 'comment_short', 'created_at']
    list_filter = ['rating', 'kitchen']
    search_fields = ['user__email', 'kitchen__name', 'comment']
    readonly_fields = ['created_at']

    def stars(self, obj):
        filled = '★' * int(obj.rating)
        empty = '☆' * (5 - int(obj.rating))
        return format_html('<span style="color:#f0ad4e;font-size:1.1em">{}{}</span>', filled, empty)
    stars.short_description = 'Rating'

    def comment_short(self, obj):
        return (obj.comment[:60] + '...') if len(obj.comment) > 60 else obj.comment
    comment_short.short_description = 'Comment'


@admin.register(Coupon)
class CouponAdmin(BulkActionsAdmin):
    list_display = ['code', 'discount_type', 'discount_value', 'min_order_value', 'max_discount', 'expiry_date', 'active_badge', 'usage_info']
    list_filter = ['discount_type', 'is_active']
    search_fields = ['code']
    readonly_fields = ['used_count']
    fieldsets = [
        ('Coupon Info', {'fields': ['code', 'discount_type', 'discount_value']}),
        ('Constraints', {'fields': ['min_order_value', 'max_discount', 'expiry_date']}),
        ('Usage', {'fields': ['is_active', 'usage_limit', 'used_count']}),
    ]

    def active_badge(self, obj):
        return badge(obj.is_active, 'Active' if obj.is_active else 'Inactive')
    active_badge.short_description = 'Active'

    def usage_info(self, obj):
        if obj.usage_limit == 0:
            return 'Unlimited'
        remaining = obj.usage_limit - obj.used_count
        color = 'success' if remaining > 0 else 'danger'
        return format_html('<span class="badge badge-{}">{}/{}</span>', color, remaining, obj.usage_limit)
    usage_info.short_description = 'Remaining'


@admin.register(SupportTicket)
class SupportTicketAdmin(BulkActionsAdmin):
    list_display = ['subject', 'user', 'status_badge', 'created_at', 'updated_at']
    list_filter = ['status']
    search_fields = ['subject', 'user__email', 'message']
    readonly_fields = ['created_at', 'updated_at']
    fieldsets = [
        ('Ticket', {'fields': ['user', 'subject', 'message']}),
        ('Status', {'fields': ['status']}),
        ('Timestamps', {'fields': ['created_at', 'updated_at']}),
    ]

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'


@admin.register(Banner)
class BannerAdmin(BulkActionsAdmin):
    list_display = ['title', 'active_badge', 'sort_order', 'created_at']
    list_editable = ['sort_order']
    list_filter = ['is_active']
    search_fields = ['title']

    def active_badge(self, obj):
        return badge(obj.is_active, 'Active' if obj.is_active else 'Inactive')
    active_badge.short_description = 'Status'


@admin.register(AdminSetting)
class AdminSettingAdmin(BulkActionsAdmin):
    list_display = ['key', 'value', 'updated_at']
    search_fields = ['key']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(PayoutRequest)
class PayoutRequestAdmin(BulkActionsAdmin):
    list_display = ['chef', 'display_amount', 'status_badge', 'requested_at', 'processed_at']
    list_filter = ['status']
    search_fields = ['chef__email', 'chef__name']
    readonly_fields = ['requested_at']
    fieldsets = [
        ('Chef', {'fields': ['chef']}),
        ('Payout', {'fields': ['amount', 'bank_details']}),
        ('Status', {'fields': ['status']}),
        ('Timestamps', {'fields': ['requested_at', 'processed_at']}),
    ]
    actions = ['export_selected_records', 'approve_payouts', 'reject_payouts']

    def display_amount(self, obj):
        return f'₹{obj.amount}'
    display_amount.short_description = 'Amount'

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'

    def approve_payouts(self, request, queryset):
        updated = queryset.update(status='approved', processed_at=timezone.now())
        self.message_user(request, f'{updated} payout(s) approved.')
    approve_payouts.short_description = 'Approve selected payouts'

    def reject_payouts(self, request, queryset):
        updated = queryset.update(status='rejected', processed_at=timezone.now())
        self.message_user(request, f'{updated} payout(s) rejected.')
    reject_payouts.short_description = 'Reject selected payouts'


@admin.register(DeliveryDocument)
class DeliveryDocumentAdmin(BulkActionsAdmin):
    list_display = ['user', 'doc_type', 'doc_number', 'status_badge', 'verification_notes', 'created_at']
    list_filter = ['doc_type', 'status']
    search_fields = ['user__email', 'user__name', 'doc_number']
    readonly_fields = ['created_at', 'updated_at']
    fieldsets = [
        ('User', {'fields': ['user']}),
        ('Document Details', {'fields': ['doc_type', 'doc_number', 'file_url']}),
        ('Verification', {'fields': ['status', 'verification_notes']}),
        ('Timestamps', {'fields': ['created_at', 'updated_at']}),
    ]
    actions = ['export_selected_records', 'approve_docs', 'reject_docs']

    def status_badge(self, obj):
        return badge(obj.status)
    status_badge.short_description = 'Status'

    def approve_docs(self, request, queryset):
        updated = queryset.update(status='verified')
        self.message_user(request, f'{updated} document(s) approved.')
    approve_docs.short_description = 'Verify selected documents'

    def reject_docs(self, request, queryset):
        updated = queryset.update(status='rejected')
        self.message_user(request, f'{updated} document(s) rejected.')
    reject_docs.short_description = 'Reject selected documents'

