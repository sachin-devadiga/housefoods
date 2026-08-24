from rest_framework import serializers
from django.utils import timezone
from .models import (
    UserProfile, Address, Kitchen, KitchenImage, KitchenCategory,
    MenuCategory, MenuItem, SubscriptionPlan, DailyMenu, Order, OrderItem,
    Cart, CartItem, DeliveryLog, Payment, WalletTransaction, Review, Coupon,
    Notification, SupportTicket, Banner, AdminSetting, PayoutRequest,
    ChatMessage, DeliveryDocument,
)


def _to_snake(name):
    import re
    s1 = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


def _to_camel(name):
    parts = name.split('_')
    return parts[0] + ''.join(p.title() for p in parts[1:])


class CamelCaseModelSerializer(serializers.ModelSerializer):
    """Accepts camelCase (app) and snake_case (API) keys on input,
    and emits camelCase aliases alongside snake_case keys on output."""

    def to_internal_value(self, data):
        if isinstance(data, dict):
            data = {_to_snake(k): v for k, v in data.items()}
        return super().to_internal_value(data)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        for key in list(rep.keys()):
            camel = _to_camel(key)
            if camel != key and camel not in rep:
                rep[camel] = rep[key]
        return rep


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            'uid', 'email', 'name', 'role', 'phone', 'avatar_url',
            'favorite_kitchen_ids', 'wallet_balance', 'fcm_token',
            'is_active', 'is_available', 'is_verified', 'created_at', 'updated_at',
        ]
        read_only_fields = ['uid', 'wallet_balance', 'is_verified', 'created_at', 'updated_at']


class UserProfileMiniSerializer(CamelCaseModelSerializer):
    dietary_preference = serializers.SerializerMethodField()
    addresses = serializers.SerializerMethodField()
    favorite_kitchen_ids = serializers.SerializerMethodField()
    wallet_balance = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    created_at = serializers.DateTimeField(read_only=True)
    referral_code = serializers.CharField(read_only=True)
    referred_by = serializers.CharField(read_only=True, allow_null=True)
    allergies = serializers.ListField(child=serializers.CharField(), required=False, default=list)

    class Meta:
        model = UserProfile
        fields = ['uid', 'name', 'email', 'role', 'avatar_url', 'phone', 'dietary_preferences', 'allergies',
                  'dietary_preference', 'addresses', 'favorite_kitchen_ids', 'wallet_balance',
                  'created_at', 'referral_code', 'referred_by', 'fcm_token']

    def get_dietary_preference(self, obj):
        prefs = obj.dietary_preferences or []
        return prefs[0] if prefs else 'none'

    def get_addresses(self, obj):
        addresses = obj.addresses.all()
        return AddressSerializer(addresses, many=True).data

    def get_favorite_kitchen_ids(self, obj):
        ids = obj.favorite_kitchen_ids or []
        return [str(i) for i in ids]


class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = ['id', 'user', 'label', 'address_line1', 'address_line2', 'landmark', 'city', 'state', 'pincode', 'latitude', 'longitude', 'is_default', 'created_at']
        read_only_fields = ['created_at', 'user']

    def create(self, validated_data):
        validated_data.pop('id', None)
        return super().create(validated_data)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['fullAddress'] = data.pop('address_line1', '')
        data['houseNo'] = data.pop('address_line2', '')
        return data


class KitchenCategorySerializer(CamelCaseModelSerializer):
    class Meta:
        model = KitchenCategory
        fields = '__all__'


class KitchenCategoriesField(serializers.ListField):
    """Outputs category names; accepts names or PKs on write."""

    def to_representation(self, value):
        return [c.name for c in value.all()]

    def to_internal_value(self, data):
        if not isinstance(data, list):
            data = [data]
        ids = []
        for item in data:
            if isinstance(item, int) or (isinstance(item, str) and item.isdigit()):
                ids.append(int(item))
            else:
                category, _ = KitchenCategory.objects.get_or_create(name=str(item).strip())
                ids.append(category.pk)
        return ids


class KitchenImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = KitchenImage
        fields = '__all__'


class MenuCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuCategory
        fields = '__all__'
        read_only_fields = ['created_at']


class MenuItemSerializer(CamelCaseModelSerializer):
    kitchen = serializers.PrimaryKeyRelatedField(
        queryset=Kitchen.objects.all(), required=False, allow_null=True, default=None
    )

    class Meta:
        model = MenuItem
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class SubscriptionPlanSerializer(CamelCaseModelSerializer):
    kitchen = serializers.PrimaryKeyRelatedField(
        queryset=Kitchen.objects.all(), required=False, allow_null=True, default=None
    )

    class Meta:
        model = SubscriptionPlan
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class DailyMenuSerializer(CamelCaseModelSerializer):
    kitchen = serializers.PrimaryKeyRelatedField(
        queryset=Kitchen.objects.all(), required=False, allow_null=True, default=None
    )

    class Meta:
        model = DailyMenu
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class KitchenSerializer(CamelCaseModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)
    plans = SubscriptionPlanSerializer(many=True, read_only=True)
    categories_detail = KitchenCategorySerializer(source='categories', many=True, read_only=True)
    categories = KitchenCategoriesField(required=False)
    daily_menus = serializers.SerializerMethodField()
    chef_name = serializers.CharField(source='chef.name', read_only=True)
    chef_id = serializers.CharField(source='chef.uid', read_only=True)

    class Meta:
        model = Kitchen
        fields = [
            'id', 'chef', 'chef_id', 'chef_details', 'chef_name',
            'name', 'description', 'status',
            'is_open', 'is_veg', 'rating', 'total_ratings', 'latitude', 'longitude',
            'address', 'phone', 'image_url', 'specialties', 'fssai_number',
            'id_proof_url', 'license_url', 'business_hours',
            'categories', 'categories_list',
            'categories_detail', 'gallery_images', 'plans', 'daily_menus',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['chef', 'rating', 'total_ratings', 'created_at', 'updated_at']

    def get_daily_menus(self, obj):
        menus = obj.daily_menus.filter(is_active=True).order_by('date')
        return DailyMenuSerializer(menus, many=True).data


class KitchenListSerializer(CamelCaseModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)
    chef_name = serializers.CharField(source='chef.name', read_only=True)
    chef_id = serializers.CharField(source='chef.uid', read_only=True)
    categories = KitchenCategoriesField(required=False)

    class Meta:
        model = Kitchen
        fields = [
            'id', 'chef', 'chef_id', 'chef_details', 'chef_name',
            'name', 'description', 'status',
            'is_open', 'is_veg', 'rating', 'total_ratings', 'latitude', 'longitude',
            'address', 'image_url', 'specialties', 'categories',
            'categories_list', 'gallery_images',
            'created_at',
        ]


class OrderItemSerializer(CamelCaseModelSerializer):
    menu_item_name = serializers.CharField(source='menu_item.name', read_only=True)
    menu_item_image = serializers.CharField(source='menu_item.image_url', read_only=True)

    class Meta:
        model = OrderItem
        fields = ['id', 'menu_item', 'menu_item_name', 'menu_item_image', 'quantity', 'price_at_order', 'special_instructions']
        read_only_fields = ['price_at_order']


class OrderSerializer(CamelCaseModelSerializer):
    kitchen_details = KitchenListSerializer(source='kitchen', read_only=True)
    customer_details = UserProfileMiniSerializer(source='customer', read_only=True)
    delivery_partner_details = UserProfileMiniSerializer(source='delivery_partner', read_only=True)
    kitchen_name = serializers.CharField(source='kitchen.name', read_only=True)
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class OrderCreateSerializer(serializers.ModelSerializer):
    items_data = OrderItemSerializer(many=True, required=False, write_only=True)

    class Meta:
        model = Order
        fields = [
            'kitchen', 'order_type', 'plan', 'plan_name', 'amount', 'subtotal',
            'tax', 'platform_fee', 'tip', 'delivery_address', 'delivery_time',
            'start_date', 'end_date', 'delivery_slot_id', 'meal_type', 'items_data',
        ]
        read_only_fields = ['plan_name']

    def create(self, validated_data):
        items_data = validated_data.pop('items_data', [])
        validated_data['customer'] = self.context['request'].user.profile

        order_type = validated_data.get('order_type', 'subscription')
        if order_type == 'one_time':
            validated_data['status'] = 'active'
            validated_data['start_date'] = validated_data.get('delivery_time', timezone.now()).date() if not validated_data.get('start_date') else validated_data['start_date']
            validated_data['end_date'] = validated_data.get('start_date')
        else:
            validated_data['status'] = 'active'
            plan = validated_data.get('plan')
            if plan and not validated_data.get('plan_name'):
                validated_data['plan_name'] = plan.name

        order = super().create(validated_data)

        if order_type == 'one_time' and items_data:
            for item_data in items_data:
                menu_item = item_data['menu_item']
                OrderItem.objects.create(
                    order=order,
                    menu_item=menu_item,
                    quantity=item_data.get('quantity', 1),
                    price_at_order=menu_item.price,
                    special_instructions=item_data.get('special_instructions', ''),
                )

        return order


class CartItemSerializer(CamelCaseModelSerializer):
    menu_item_name = serializers.CharField(source='menu_item.name', read_only=True)
    menu_item_image = serializers.CharField(source='menu_item.image_url', read_only=True)
    menu_item_price = serializers.DecimalField(source='menu_item.price', max_digits=10, decimal_places=2, read_only=True)
    item_total = serializers.SerializerMethodField()

    class Meta:
        model = CartItem
        fields = ['id', 'menu_item', 'menu_item_name', 'menu_item_image', 'menu_item_price', 'quantity', 'special_instructions', 'item_total']
        read_only_fields = ['item_total']

    def get_item_total(self, obj):
        return float(obj.menu_item.price * obj.quantity)


class CartSerializer(CamelCaseModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)
    total_item_count = serializers.IntegerField(read_only=True)
    subtotal = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    kitchen_name = serializers.CharField(source='kitchen.name', read_only=True)

    class Meta:
        model = Cart
        fields = ['id', 'kitchen', 'kitchen_name', 'items', 'total_item_count', 'subtotal', 'updated_at']
        read_only_fields = ['subtotal', 'total_item_count']


class DeliveryLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryLog
        fields = '__all__'
        read_only_fields = ['created_at', 'delivered_by']


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ['created_at']


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = '__all__'
        read_only_fields = ['created_at']


class ReviewSerializer(serializers.ModelSerializer):
    user_details = UserProfileMiniSerializer(source='user', read_only=True)

    class Meta:
        model = Review
        fields = '__all__'
        read_only_fields = ['created_at']


class ReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['kitchen', 'rating', 'comment']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user.profile
        return super().create(validated_data)


class CouponSerializer(CamelCaseModelSerializer):
    class Meta:
        model = Coupon
        fields = '__all__'
        read_only_fields = ['created_at']


class CouponValidateSerializer(serializers.Serializer):
    code = serializers.CharField()
    order_amount = serializers.DecimalField(max_digits=10, decimal_places=2)


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'
        read_only_fields = ['created_at']


class SupportTicketSerializer(CamelCaseModelSerializer):
    user_details = UserProfileMiniSerializer(source='user', read_only=True)

    class Meta:
        model = SupportTicket
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class SupportTicketCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = ['subject', 'message']

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user.profile
        return super().create(validated_data)


class BannerSerializer(CamelCaseModelSerializer):
    class Meta:
        model = Banner
        fields = '__all__'
        read_only_fields = ['created_at']


class AdminSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminSetting
        fields = '__all__'


class PayoutRequestSerializer(CamelCaseModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)
    bank_name = serializers.SerializerMethodField()
    account_number = serializers.SerializerMethodField()
    ifsc_code = serializers.SerializerMethodField()
    chef_name = serializers.SerializerMethodField()
    chef_id = serializers.SerializerMethodField()

    class Meta:
        model = PayoutRequest
        fields = '__all__'
        read_only_fields = ['requested_at', 'processed_at']

    def get_bank_name(self, obj):
        return (obj.bank_details or {}).get('bank_name', '')

    def get_account_number(self, obj):
        return (obj.bank_details or {}).get('account_number', '')

    def get_ifsc_code(self, obj):
        return (obj.bank_details or {}).get('ifsc_code', '')

    def get_chef_name(self, obj):
        return obj.chef.name

    def get_chef_id(self, obj):
        return obj.chef.uid


class PayoutRequestCreateSerializer(CamelCaseModelSerializer):
    bank_name = serializers.CharField(required=False, allow_blank=True)
    account_number = serializers.CharField(required=False, allow_blank=True)
    ifsc_code = serializers.CharField(required=False, allow_blank=True)
    bank_details = serializers.JSONField(required=False)

    class Meta:
        model = PayoutRequest
        fields = ['amount', 'bank_details', 'bank_name', 'account_number', 'ifsc_code']

    def create(self, validated_data):
        bank_details = validated_data.pop('bank_details', {}) or {}
        bank_name = validated_data.pop('bank_name', '')
        account_number = validated_data.pop('account_number', '')
        ifsc_code = validated_data.pop('ifsc_code', '')
        if bank_name or account_number or ifsc_code:
            bank_details = {
                'bank_name': bank_name or bank_details.get('bank_name', ''),
                'account_number': account_number or bank_details.get('account_number', ''),
                'ifsc_code': ifsc_code or bank_details.get('ifsc_code', ''),
            }
        validated_data['bank_details'] = bank_details
        validated_data['chef'] = self.context['request'].user.profile
        return super().create(validated_data)


class ChatMessageSerializer(serializers.ModelSerializer):
    sender_details = UserProfileMiniSerializer(source='sender', read_only=True)
    receiver_details = UserProfileMiniSerializer(source='receiver', read_only=True)

    class Meta:
        model = ChatMessage
        fields = '__all__'
        read_only_fields = ['created_at']


class ChatMessageCreateSerializer(serializers.ModelSerializer):
    receiver = serializers.CharField()

    class Meta:
        model = ChatMessage
        fields = ['receiver', 'kitchen', 'message', 'message_type']

    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user.profile
        receiver_val = validated_data.pop('receiver')
        try:
            receiver_profile = UserProfile.objects.get(uid=receiver_val)
        except UserProfile.DoesNotExist:
            try:
                receiver_profile = UserProfile.objects.get(pk=int(receiver_val))
            except (ValueError, UserProfile.DoesNotExist):
                from rest_framework.exceptions import ValidationError
                raise ValidationError({'receiver': 'Invalid receiver UID or ID'})
        validated_data['receiver'] = receiver_profile
        return super().create(validated_data)


class LoginResponseSerializer(serializers.Serializer):
    access_token = serializers.CharField()
    refresh_token = serializers.CharField()
    user = UserProfileSerializer()


class DeliveryDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryDocument
        fields = [
            'id', 'doc_type', 'doc_number', 'file_url', 'status',
            'verification_notes', 'digilocker_doc_id', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'status', 'verification_notes', 'created_at', 'updated_at']


class AdminDeliveryDocumentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.name', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)

    class Meta:
        model = DeliveryDocument
        fields = [
            'id', 'user', 'user_name', 'user_email', 'doc_type', 'doc_number',
            'file_url', 'status', 'verification_notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user', 'doc_type', 'doc_number', 'file_url', 'created_at', 'updated_at']


class AdminDeliveryPartnerSerializer(serializers.ModelSerializer):
    documents = serializers.SerializerMethodField()

    class Meta:
        model = UserProfile
        fields = [
            'uid', 'email', 'name', 'phone', 'is_verified', 'is_available',
            'is_active', 'documents', 'created_at',
        ]

    def get_documents(self, obj):
        docs = DeliveryDocument.objects.filter(user=obj)
        return DeliveryDocumentSerializer(docs, many=True).data


class ProfileSetupSerializer(serializers.Serializer):
    name = serializers.CharField(required=True, max_length=255)
    role = serializers.ChoiceField(
        choices=['customer', 'chef', 'delivery_partner']
    )
    phone = serializers.CharField(required=False, allow_blank=True, max_length=20)
    avatar_url = serializers.CharField(required=False, allow_blank=True, max_length=500)
    dietary_preferences = serializers.ListField(
        child=serializers.CharField(), required=False, allow_empty=True
    )
    allergies = serializers.ListField(
        child=serializers.CharField(), required=False, allow_empty=True
    )
