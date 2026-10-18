import uuid
import random
from datetime import timedelta
from decimal import Decimal
from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User


class OTP(models.Model):
    email = models.EmailField()
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.IntegerField(default=0)
    is_verified = models.BooleanField(default=False)

    class Meta:
        indexes = [
            models.Index(fields=['email', 'is_verified']),
        ]

    @classmethod
    def generate(cls, email):
        cls.objects.filter(email=email, is_verified=False).delete()
        code = f'{random.randint(0, 999999):06d}'
        now = timezone.now()
        return cls.objects.create(
            email=email,
            code=code,
            created_at=now,
            expires_at=now + timedelta(minutes=5),
        )

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    @property
    def can_resend(self):
        return timezone.now() > self.created_at + timedelta(seconds=60)

    def __str__(self):
        return f'{self.email} - {self.code}'


class UserProfile(models.Model):
    ROLE_CHOICES = [
        ('customer', 'Customer'),
        ('chef', 'Chef'),
        ('delivery_partner', 'Delivery Partner'),
        ('admin', 'Admin'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    uid = models.CharField(max_length=128, unique=True, blank=True)
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=255, blank=True, default='')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='customer')
    phone = models.CharField(max_length=20, blank=True, default='')
    avatar_url = models.CharField(max_length=500, blank=True, default='')
    favorite_kitchen_ids = models.JSONField(default=list, blank=True)
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    fcm_token = models.CharField(max_length=500, blank=True, default='')
    dietary_preferences = models.JSONField(default=list, blank=True)
    allergies = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    is_available = models.BooleanField(default=True)
    is_verified = models.BooleanField(default=False)
    current_latitude = models.FloatField(null=True, blank=True)
    current_longitude = models.FloatField(null=True, blank=True)
    location_updated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_profiles'
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['role']),
        ]

    def save(self, *args, **kwargs):
        if not self.uid:
            self.uid = str(uuid.uuid4()).replace('-', '')[:28]
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.email} ({self.role})'


class Address(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='addresses')
    label = models.CharField(max_length=100, blank=True, default='')
    address_line1 = models.CharField(max_length=255)
    address_line2 = models.CharField(max_length=255, blank=True, default='')
    landmark = models.CharField(max_length=255, blank=True, default='')
    city = models.CharField(max_length=100, default='')
    state = models.CharField(max_length=100, default='')
    pincode = models.CharField(max_length=10, default='')
    latitude = models.FloatField(default=0.0)
    longitude = models.FloatField(default=0.0)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'addresses'

    def __str__(self):
        return f'{self.address_line1}, {self.city}'


class KitchenCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)
    icon = models.CharField(max_length=100, blank=True, default='')
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'kitchen_categories'
        ordering = ['sort_order', 'name']

    def __str__(self):
        return self.name


class Kitchen(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    chef = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='kitchens')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_open = models.BooleanField(default=True)
    is_veg = models.BooleanField(default=False)
    rating = models.FloatField(default=0.0)
    total_ratings = models.IntegerField(default=0)
    latitude = models.FloatField(default=0.0)
    longitude = models.FloatField(default=0.0)
    address = models.TextField(blank=True, default='')
    phone = models.CharField(max_length=20, blank=True, default='')
    image_url = models.CharField(max_length=500, blank=True, default='')
    specialties = models.JSONField(default=list, blank=True)
    fssai_number = models.CharField(max_length=100, blank=True, default='')
    id_proof_url = models.CharField(max_length=500, blank=True, default='')
    license_url = models.CharField(max_length=500, blank=True, default='')
    business_hours = models.JSONField(default=dict, blank=True)
    categories = models.ManyToManyField(KitchenCategory, blank=True, related_name='kitchens')
    categories_list = models.JSONField(default=list, blank=True)
    gallery_images = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'kitchens'
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['chef']),
        ]

    def __str__(self):
        return self.name


class KitchenImage(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='images')
    image_url = models.CharField(max_length=500)
    is_primary = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'kitchen_images'

    def __str__(self):
        return f'Image for {self.kitchen.name}'


class MenuCategory(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='menu_categories')
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, default='')
    sort_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'menu_categories'
        ordering = ['sort_order', 'name']
        unique_together = ['kitchen', 'name']

    def __str__(self):
        return f'{self.kitchen.name} - {self.name}'


class MenuItem(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='menu_items')
    category = models.ForeignKey(MenuCategory, on_delete=models.SET_NULL, null=True, blank=True, related_name='items')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    price = models.DecimalField(max_digits=8, decimal_places=2)
    image_url = models.CharField(max_length=500, blank=True, default='')
    is_available = models.BooleanField(default=True)
    is_veg = models.BooleanField(default=True)
    preparation_time = models.IntegerField(default=30)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'menu_items'
        indexes = [
            models.Index(fields=['kitchen', 'is_available']),
        ]

    def __str__(self):
        return self.name


class Order(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('active', 'Active'),
        ('paused', 'Paused'),
        ('cancelled', 'Cancelled'),
        ('completed', 'Completed'),
    ]
    DELIVERY_STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('ready_for_delivery', 'Ready for Delivery'),
        ('assigned', 'Assigned'),
        ('picked_up', 'Picked Up'),
        ('delivered', 'Delivered'),
    ]

    ORDER_TYPE_CHOICES = [
        ('one_time', 'One-Time Order'),
        ('subscription', 'Subscription Meal'),
    ]

    customer = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='orders')
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='orders')
    order_type = models.CharField(max_length=20, choices=ORDER_TYPE_CHOICES, default='one_time')
    plan_name = models.CharField(max_length=255, blank=True, default='')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    subtotal = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    tax = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    platform_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    tip = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    delivery_address = models.TextField()
    delivery_time = models.DateTimeField(null=True, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_status = models.CharField(max_length=20, choices=DELIVERY_STATUS_CHOICES, default='pending')
    payment_id = models.CharField(max_length=255, blank=True, default='')

    # --- Payment tracking -------------------------------------------------
    # `payment_id` alone cannot distinguish a Razorpay payment from a COD
    # order: both end up with the same empty string until a payment exists.
    # Without these, chef earnings and admin revenue summed every order the
    # moment it was created, so uncollected cash counted as income.
    PAYMENT_METHOD_CHOICES = [
        ('online', 'Online'),
        ('cod', 'Cash on Delivery'),
    ]
    payment_method = models.CharField(
        max_length=10, choices=PAYMENT_METHOD_CHOICES, default='online',
    )
    # COD is settled by the rider at handover; online is settled up-front.
    # Payouts stay held until an order is BOTH delivered and paid.
    is_paid = models.BooleanField(default=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    delivery_partner = models.ForeignKey(
        UserProfile, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='delivery_orders'
    )
    delivery_slot_id = models.CharField(max_length=100, blank=True, default='')
    meal_type = models.CharField(max_length=100, blank=True, default='')
    preparation_time = models.IntegerField(default=0)
    is_paused = models.BooleanField(default=False)
    delivery_fee = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    # What the rider earns for this order. Deliberately separate from
    # delivery_fee (what the customer was charged): for subscription meals the
    # two are equal, for one-time orders the customer pays nothing and the
    # rider earns the admin-set wage. Conflating them would make one column
    # mean two different things the moment checkout starts displaying it.
    rider_payout = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    assigned_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_otp = models.CharField(max_length=6, blank=True, default='')
    delivery_latitude = models.FloatField(null=True, blank=True)
    delivery_longitude = models.FloatField(null=True, blank=True)
    eta_5min_notified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'orders'
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['kitchen', 'status']),
            models.Index(fields=['delivery_partner', 'delivery_status']),
            # Chef earnings and payout eligibility both filter on this.
            models.Index(fields=['kitchen', 'is_paid']),
        ]

    def __str__(self):
        return f'Order #{self.id} - {self.customer.email}'

    @property
    def is_cod(self):
        return self.payment_method == 'cod'

    @property
    def payout_eligible(self):
        """True when this order may count toward a chef's payout.

        Both conditions matter: cash that has not been collected must not be
        paid out, and neither must a meal that has not been delivered.
        """
        return self.is_paid and self.delivery_status == 'delivered'


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=1)
    price_at_order = models.DecimalField(max_digits=10, decimal_places=2)
    special_instructions = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'order_items'

    def __str__(self):
        return f'{self.quantity}x {self.menu_item.name} (Order #{self.order.id})'


class Cart(models.Model):
    user = models.OneToOneField(UserProfile, on_delete=models.CASCADE, related_name='cart')
    kitchen = models.ForeignKey(Kitchen, on_delete=models.SET_NULL, null=True, blank=True, related_name='carts')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'carts'

    def __str__(self):
        return f'Cart for {self.user.email}'

    @property
    def total_item_count(self):
        return sum(item.quantity for item in self.items.all())

    @property
    def subtotal(self):
        return sum(item.quantity * item.menu_item.price for item in self.items.all())


class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name='items')
    menu_item = models.ForeignKey(MenuItem, on_delete=models.CASCADE)
    quantity = models.IntegerField(default=1)
    special_instructions = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'cart_items'
        unique_together = ['cart', 'menu_item']

    def __str__(self):
        return f'{self.quantity}x {self.menu_item.name}'


class DeliveryLog(models.Model):
    STATUS_CHOICES = [
        ('delivered', 'Delivered'),
        ('skipped', 'Skipped'),
        ('missed', 'Missed'),
    ]

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='delivery_logs')
    date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='delivered')
    refund_amount = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    rating = models.FloatField(null=True, blank=True)
    feedback = models.TextField(blank=True, default='')
    delivered_by = models.ForeignKey(
        UserProfile, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='delivery_logs'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'delivery_logs'
        unique_together = ['order', 'date']

    def __str__(self):
        return f'{self.order.id} - {self.date} - {self.status}'


class Payment(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='payments')
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_id = models.CharField(max_length=255, blank=True, default='')
    status = models.CharField(max_length=50, default='created')
    method = models.CharField(max_length=50, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'payments'

    def __str__(self):
        return f'Payment {self.payment_id} - {self.amount}'


class WalletTransaction(models.Model):
    TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
    ]
    CATEGORIES = [
        ('refund', 'Refund'),
        ('order_payment', 'Order Payment'),
        ('referral', 'Referral Bonus'),
        ('top_up', 'Top Up'),
        ('payout', 'Payout'),
    ]

    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='wallet_transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    type = models.CharField(max_length=10, choices=TYPES)
    category = models.CharField(max_length=50, choices=CATEGORIES)
    description = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'wallet_transactions'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.email} - {self.type} - {self.amount}'


class Review(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='reviews')
    rating = models.FloatField()
    comment = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'reviews'
        unique_together = ['kitchen', 'user']
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.email} - {self.kitchen.name} - {self.rating}'


class Coupon(models.Model):
    DISCOUNT_TYPES = [
        ('flat', 'Flat'),
        ('percentage', 'Percentage'),
    ]

    code = models.CharField(max_length=50, unique=True)
    discount_type = models.CharField(max_length=10, choices=DISCOUNT_TYPES)
    discount_value = models.DecimalField(max_digits=8, decimal_places=2)
    min_order_value = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    max_discount = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    expiry_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    usage_limit = models.IntegerField(default=0)
    used_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'coupons'

    def __str__(self):
        return self.code


class Notification(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    body = models.TextField()
    type = models.CharField(max_length=50, blank=True, default='')
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.email} - {self.title}'


class SupportTicket(models.Model):
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
    ]

    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='support_tickets')
    subject = models.CharField(max_length=255)
    message = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'support_tickets'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.subject} - {self.user.email}'


class Banner(models.Model):
    title = models.CharField(max_length=255, blank=True, default='')
    image_url = models.CharField(max_length=500)
    link = models.CharField(max_length=500, blank=True, default='')
    is_active = models.BooleanField(default=True)
    sort_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'banners'
        ordering = ['sort_order']

    def __str__(self):
        return self.title or f'Banner {self.id}'


class AdminSetting(models.Model):
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'admin_settings'

    def __str__(self):
        return self.key


class PayoutRequest(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('paid', 'Paid'),
    ]

    chef = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='payout_requests', null=True, blank=True)
    delivery_partner = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='delivery_payout_requests', null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    bank_details = models.JSONField(default=dict, blank=True)
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'payout_requests'
        ordering = ['-requested_at']

    def __str__(self):
        payer = self.chef or self.delivery_partner
        return f'{payer.email} - {self.amount} - {self.status}'


class DeliveryDocument(models.Model):
    DOC_TYPES = [
        ('aadhar', 'Aadhar Card'),
        ('pan', 'PAN Card'),
        ('driving_license', 'Driving License'),
    ]
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('verified', 'Verified'),
        ('rejected', 'Rejected'),
    ]

    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='delivery_documents')
    doc_type = models.CharField(max_length=20, choices=DOC_TYPES)
    doc_number = models.CharField(max_length=100, blank=True, default='')
    file_url = models.CharField(max_length=500, blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    verification_notes = models.TextField(blank=True, default='')
    digilocker_doc_id = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'delivery_documents'
        unique_together = ['user', 'doc_type']

    def __str__(self):
        return f'{self.user.email} - {self.doc_type} - {self.status}'


class ChatMessage(models.Model):
    sender = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='sent_messages')
    receiver = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='received_messages')
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, null=True, blank=True)
    message = models.TextField()
    message_type = models.CharField(max_length=20, default='text')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'chat_messages'
        ordering = ['created_at']

    def __str__(self):
        return f'{self.sender.email} -> {self.receiver.email}: {self.message[:50]}'


class VoicePin(models.Model):
    user = models.OneToOneField(UserProfile, on_delete=models.CASCADE, related_name='voice_pin')
    pin_hash = models.CharField(max_length=256)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    failed_attempts = models.IntegerField(default=0)
    locked_until = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'voice_pins'

    def __str__(self):
        return f'Voice PIN for {self.user.email}'


class VoiceAuthorization(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='voice_authorizations')
    token = models.CharField(max_length=64, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_consumed = models.BooleanField(default=False)
    order_id = models.IntegerField(null=True, blank=True)

    class Meta:
        db_table = 'voice_authorizations'
        indexes = [
            models.Index(fields=['user', 'is_consumed']),
            models.Index(fields=['token']),
        ]

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    def __str__(self):
        return f'VoiceAuth {self.token[:8]}... for {self.user.email}'


# ──────────────────────────────────────────────
# SUBSCRIPTIONS
#
# A subscription is a recurring meal plan a customer buys from a Kitchen.
#
# The kitchen publishes a weekly template (PlanSlot): for each day_of_week x
# meal_type it says what it will cook. A subscription picks one template plus a
# billing cadence (week / month / year). The recurring work is materialised as
# SubscriptionMeal rows, which are created at most 7 days ahead and each
# become exactly one real Order when due. Keeping the two steps separate is
# what makes skip / pause / edit-the-week possible without rewriting history.
#
# Money is Decimal throughout. Never float.

class MealPlan(models.Model):
    """A meal plan a kitchen offers. Pricing and weekly contents hang off it."""

    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='meal_plans')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    inclusions = models.JSONField(default=list, blank=True)
    is_veg = models.BooleanField(default=True)
    image_url = models.CharField(max_length=500, blank=True, default='')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'meal_plans'
        indexes = [
            models.Index(fields=['kitchen', 'is_active']),
        ]

    def __str__(self):
        return f'{self.kitchen.name} - {self.name}'

    @property
    def starting_price(self):
        """Cheapest active price, for sorting cards without an extra query."""
        active = [p.price for p in self.prices.filter(is_active=True)]
        return min(active) if active else None


class PlanPrice(models.Model):
    """One billable cadence for a plan. Cadence is data, not code."""

    CADENCE_CHOICES = [
        ('week', 'Weekly'),
        ('month', 'Monthly'),
        ('year', 'Yearly'),
    ]
    DURATION_DAYS = {
        'week': 7,
        'month': 30,
        'year': 365,
    }
    # Membership-testable form of CADENCE_CHOICES (which is a list of tuples).
    CADENCE_DICT = dict(CADENCE_CHOICES)

    plan = models.ForeignKey(MealPlan, on_delete=models.CASCADE, related_name='prices')
    cadence = models.CharField(max_length=10, choices=CADENCE_CHOICES)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'plan_prices'
        constraints = [
            models.UniqueConstraint(fields=['plan', 'cadence'], name='uniq_plan_cadence'),
        ]
        indexes = [
            models.Index(fields=['plan', 'is_active']),
        ]

    @property
    def duration_days(self):
        return self.DURATION_DAYS.get(self.cadence, 30)

    def __str__(self):
        return f'{self.plan.name} ({self.cadence}) - {self.price}'


class PlanSlot(models.Model):
    """One cell of the kitchen's weekly template: e.g. Monday dinner.

    ``items`` is a list of dicts ``{menu_item, name, qty, price}`` captured at
    publish time. Snapshotting name/price means editing a menu item later does
    not retroactively change what an existing subscriber signed up for.
    """

    MEAL_TYPE_CHOICES = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('dinner', 'Dinner'),
    ]
    DAY_CHOICES = [
        (0, 'Monday'),
        (1, 'Tuesday'),
        (2, 'Wednesday'),
        (3, 'Thursday'),
        (4, 'Friday'),
        (5, 'Saturday'),
        (6, 'Sunday'),
    ]
    MEAL_TYPE_DICT = dict(MEAL_TYPE_CHOICES)
    DAY_DICT = dict(DAY_CHOICES)

    plan = models.ForeignKey(MealPlan, on_delete=models.CASCADE, related_name='slots')
    day_of_week = models.IntegerField(choices=DAY_CHOICES)
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPE_CHOICES)
    title = models.CharField(max_length=255, blank=True, default='')
    items = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'plan_slots'
        constraints = [
            models.UniqueConstraint(
                fields=['plan', 'day_of_week', 'meal_type'], name='uniq_plan_slot',
            ),
        ]
        indexes = [
            models.Index(fields=['plan', 'is_active']),
        ]

    def __str__(self):
        return f'{self.plan.name} - {self.get_day_of_week_display()} {self.meal_type}'

    @property
    def slot_total(self):
        return sum((Decimal(str(i.get('price', 0))) * int(i.get('qty', 1))
                    for i in self.items if isinstance(i, dict)), Decimal('0'))


class Subscription(models.Model):
    """A customer subscribing to a kitchen's plan on a billing cadence."""

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('paused', 'Paused'),
        ('cancelled', 'Cancelled'),
        ('expired', 'Expired'),
    ]

    customer = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='subscriptions')
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='subscriptions')
    plan = models.ForeignKey(MealPlan, on_delete=models.PROTECT, related_name='subscriptions')
    cadence = models.CharField(max_length=10, choices=PlanPrice.CADENCE_CHOICES)
    address = models.ForeignKey(Address, on_delete=models.PROTECT, related_name='subscriptions')

    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')

    # Charged up-front per period. Renewals overwrite price_paid/payment_id.
    price_paid = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    payment_id = models.CharField(max_length=255, blank=True, default='')
    period_start = models.DateField(null=True, blank=True)
    last_charged_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'subscriptions'
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['kitchen', 'status']),
            models.Index(fields=['status', 'start_date', 'end_date']),
        ]

    def __str__(self):
        return f'{self.customer.email} -> {self.plan.name} ({self.cadence})'

    @property
    def is_current(self):
        today = timezone.now().date()
        return self.status == 'active' and self.start_date <= today <= self.end_date

    def extend(self, days):
        """Roll the window forward one period from wherever it currently ends."""
        self.end_date = self.end_date + timedelta(days=days)
        self.start_date = min(self.start_date, self.end_date)
        self.save(update_fields=['end_date', 'start_date', 'updated_at'])


class SubscriptionMeal(models.Model):
    """A single scheduled delivery. Created <=7 days ahead, becomes one Order.

    ``status``:
      scheduled - materialised, no Order yet
      ordered   - converted, ``order`` is set
      skipped   - customer skipped this meal; nothing is delivered
      delivered - its Order reached delivery_status=delivered (mirror, for
                  reporting without joining across orders)
    """

    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('ordered', 'Ordered'),
        ('skipped', 'Skipped'),
        ('delivered', 'Delivered'),
    ]

    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE, related_name='meals')
    slot = models.ForeignKey(PlanSlot, on_delete=models.SET_NULL, null=True, blank=True, related_name='meals')
    date = models.DateField()
    meal_type = models.CharField(max_length=20, choices=PlanSlot.MEAL_TYPE_CHOICES)
    title = models.CharField(max_length=255, blank=True, default='')
    items = models.JSONField(default=list, blank=True)
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name='subscription_meals')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    skip_reason = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'subscription_meals'
        constraints = [
            models.UniqueConstraint(
                fields=['subscription', 'date', 'meal_type'], name='uniq_sub_meal',
            ),
        ]
        indexes = [
            models.Index(fields=['status', 'date']),
            models.Index(fields=['subscription', 'date']),
        ]

    def __str__(self):
        return f'{self.subscription_id} - {self.date} {self.meal_type} ({self.status})'

    @property
    def item_total(self):
        return sum((Decimal(str(i.get('price', 0))) * int(i.get('qty', 1))
                    for i in self.items if isinstance(i, dict)), Decimal('0'))
