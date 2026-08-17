import uuid
import random
from datetime import timedelta
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


class SubscriptionPlan(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='plans')
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    price = models.DecimalField(max_digits=10, decimal_places=2)
    duration_days = models.IntegerField(default=30)
    meals_per_day = models.IntegerField(default=1)
    inclusions = models.JSONField(default=list, blank=True)
    is_veg = models.BooleanField(default=True)
    image_url = models.CharField(max_length=500, blank=True, default='')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'subscription_plans'

    def __str__(self):
        return f'{self.kitchen.name} - {self.name}'


class DailyMenu(models.Model):
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='daily_menus')
    date = models.DateField()
    meal_title = models.CharField(max_length=255, blank=True, default='')
    description = models.TextField(blank=True, default='')
    image_url = models.CharField(max_length=500, blank=True, default='')
    is_veg = models.BooleanField(default=True)
    items = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'daily_menus'
        unique_together = ['kitchen', 'date']

    def __str__(self):
        return f'{self.kitchen.name} - {self.date}'


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
        ('ready_for_delivery', 'Ready for Delivery'),
        ('assigned', 'Assigned'),
        ('picked_up', 'Picked Up'),
        ('delivered', 'Delivered'),
    ]

    customer = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='orders')
    kitchen = models.ForeignKey(Kitchen, on_delete=models.CASCADE, related_name='orders')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True, blank=True)
    plan_name = models.CharField(max_length=255, blank=True, default='')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    delivery_address = models.TextField()
    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_status = models.CharField(max_length=20, choices=DELIVERY_STATUS_CHOICES, default='pending')
    payment_id = models.CharField(max_length=255, blank=True, default='')
    delivery_partner = models.ForeignKey(
        UserProfile, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='delivery_orders'
    )
    delivery_slot_id = models.CharField(max_length=100, blank=True, default='')
    meal_type = models.CharField(max_length=100, blank=True, default='')
    is_paused = models.BooleanField(default=False)
    delivery_fee = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    assigned_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_otp = models.CharField(max_length=6, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'orders'
        indexes = [
            models.Index(fields=['customer', 'status']),
            models.Index(fields=['kitchen', 'status']),
            models.Index(fields=['delivery_partner', 'delivery_status']),
        ]

    def __str__(self):
        return f'Order #{self.id} - {self.customer.email}'


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

    chef = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='payout_requests')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    bank_details = models.JSONField(default=dict, blank=True)
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'payout_requests'
        ordering = ['-requested_at']

    def __str__(self):
        return f'{self.chef.email} - {self.amount} - {self.status}'


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
