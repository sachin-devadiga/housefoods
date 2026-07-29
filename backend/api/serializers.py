from rest_framework import serializers
from .models import (
    UserProfile, Address, Kitchen, KitchenImage, KitchenCategory,
    MenuCategory, MenuItem, SubscriptionPlan, DailyMenu, Order,
    DeliveryLog, Payment, WalletTransaction, Review, Coupon,
    Notification, SupportTicket, Banner, AdminSetting, PayoutRequest,
    ChatMessage, DeliveryDocument,
)


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            'uid', 'email', 'name', 'role', 'phone', 'avatar_url',
            'favorite_kitchen_ids', 'wallet_balance', 'fcm_token',
            'is_active', 'is_available', 'is_verified', 'created_at', 'updated_at',
        ]
        read_only_fields = ['uid', 'wallet_balance', 'is_verified', 'created_at', 'updated_at']


class UserProfileMiniSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['uid', 'name', 'email', 'role', 'avatar_url']


class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = '__all__'
        read_only_fields = ['created_at']


class KitchenCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = KitchenCategory
        fields = '__all__'


class KitchenImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = KitchenImage
        fields = '__all__'


class MenuCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuCategory
        fields = '__all__'
        read_only_fields = ['created_at']


class MenuItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = MenuItem
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class DailyMenuSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyMenu
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class KitchenSerializer(serializers.ModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)
    plans = SubscriptionPlanSerializer(many=True, read_only=True)
    categories_detail = KitchenCategorySerializer(source='categories', many=True, read_only=True)

    class Meta:
        model = Kitchen
        fields = [
            'id', 'chef', 'chef_details', 'name', 'description', 'status',
            'is_open', 'rating', 'total_ratings', 'latitude', 'longitude',
            'address', 'phone', 'categories', 'categories_list',
            'categories_detail', 'gallery_images', 'plans',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['chef', 'rating', 'total_ratings', 'created_at', 'updated_at']


class KitchenListSerializer(serializers.ModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)

    class Meta:
        model = Kitchen
        fields = [
            'id', 'chef', 'chef_details', 'name', 'description', 'status',
            'is_open', 'rating', 'total_ratings', 'latitude', 'longitude',
            'address', 'categories_list', 'gallery_images',
            'created_at',
        ]


class OrderSerializer(serializers.ModelSerializer):
    kitchen_details = KitchenListSerializer(source='kitchen', read_only=True)
    customer_details = UserProfileMiniSerializer(source='customer', read_only=True)
    delivery_partner_details = UserProfileMiniSerializer(source='delivery_partner', read_only=True)

    class Meta:
        model = Order
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class OrderCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = [
            'kitchen', 'plan', 'plan_name', 'amount', 'delivery_address',
            'start_date', 'end_date', 'delivery_slot_id', 'meal_type',
        ]
        read_only_fields = ['plan_name']

    def create(self, validated_data):
        validated_data['customer'] = self.context['request'].user.profile
        validated_data['status'] = 'active'
        plan = validated_data.get('plan')
        if plan and not validated_data.get('plan_name'):
            validated_data['plan_name'] = plan.name
        return super().create(validated_data)


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


class CouponSerializer(serializers.ModelSerializer):
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


class SupportTicketSerializer(serializers.ModelSerializer):
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


class BannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Banner
        fields = '__all__'
        read_only_fields = ['created_at']


class AdminSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminSetting
        fields = '__all__'


class PayoutRequestSerializer(serializers.ModelSerializer):
    chef_details = UserProfileMiniSerializer(source='chef', read_only=True)

    class Meta:
        model = PayoutRequest
        fields = '__all__'
        read_only_fields = ['requested_at', 'processed_at']


class PayoutRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PayoutRequest
        fields = ['amount', 'bank_details']

    def create(self, validated_data):
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
    class Meta:
        model = ChatMessage
        fields = ['receiver', 'kitchen', 'message', 'message_type']

    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user.profile
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
