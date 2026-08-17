import os
import random
import time
import uuid
from datetime import timedelta
from decimal import Decimal

import requests

from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.db.models import Count, Sum, Q, Avg
from django.utils import timezone
from rest_framework import status, generics, viewsets, mixins
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from .models import (
    OTP, UserProfile, Address, Kitchen, KitchenImage, KitchenCategory,
    MenuCategory, MenuItem, SubscriptionPlan, DailyMenu, Order,
    DeliveryLog, Payment, WalletTransaction, Review, Coupon,
    Notification, SupportTicket, Banner, AdminSetting, PayoutRequest,
    ChatMessage, DeliveryDocument,
)
from .otp_utils import send_otp_email, send_otp_email_async, t0, tlog, elapsed
from .serializers import (
    UserProfileSerializer, UserProfileMiniSerializer, AddressSerializer,
    KitchenCategorySerializer, KitchenSerializer, KitchenListSerializer,
    MenuCategorySerializer, MenuItemSerializer, SubscriptionPlanSerializer,
    DailyMenuSerializer, OrderSerializer, OrderCreateSerializer,
    DeliveryLogSerializer, PaymentSerializer, WalletTransactionSerializer,
    ReviewSerializer, ReviewCreateSerializer, CouponSerializer,
    CouponValidateSerializer, NotificationSerializer,
    SupportTicketSerializer, SupportTicketCreateSerializer,
    BannerSerializer, AdminSettingSerializer, PayoutRequestSerializer,
    PayoutRequestCreateSerializer, ChatMessageSerializer,
    ChatMessageCreateSerializer, LoginResponseSerializer,
    ProfileSetupSerializer, DeliveryDocumentSerializer,
    AdminDeliveryDocumentSerializer, AdminDeliveryPartnerSerializer,
)
from .permissions import IsAdmin, IsChef, IsCustomer, IsDeliveryPartner


# ──────────────────────────────────────────────
# AUTHENTICATION VIEWS
# ──────────────────────────────────────────────

class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        t0()
        tlog('Request received')

        email = request.data.get('email', '').strip().lower()
        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        existing = OTP.objects.filter(email=email, is_verified=False).last()
        if existing and not existing.can_resend:
            return Response(
                {'error': 'Please wait 60 seconds before requesting a new OTP'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        otp = OTP.generate(email)
        tlog(f'OTP generated and saved: {otp.code}')

        # Dispatch email to background thread — response returns immediately
        send_otp_email_async(otp.email, otp.code)

        tlog('Response sent')
        resp = {'message': 'OTP sent successfully', 'email': email, 'otp_code': otp.code}
        return Response(resp)


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        code = request.data.get('otp', '').strip()

        if not email or not code:
            return Response({'error': 'Email and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)

        otp = OTP.objects.filter(email=email, is_verified=False).last()
        if not otp:
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

        if otp.is_expired:
            otp.delete()
            return Response({'error': 'OTP has expired. Please request a new one.'}, status=status.HTTP_400_BAD_REQUEST)

        if otp.attempts >= 5:
            otp.delete()
            return Response({'error': 'Too many failed attempts. Please request a new OTP.'}, status=status.HTTP_400_BAD_REQUEST)

        if otp.code != code:
            otp.attempts += 1
            otp.save()
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

        otp.is_verified = True
        otp.save()

        user = User.objects.filter(username=email).first()
        if user is None:
            return Response({
                'success': True,
                'email': email,
                'profile_exists': False,
            })

        profile = UserProfile.objects.filter(user=user).first()
        if profile is None:
            return Response({
                'success': True,
                'email': email,
                'profile_exists': False,
            })

        refresh = RefreshToken.for_user(user)
        access_token = str(refresh.access_token)
        refresh_token = str(refresh)

        return Response({
            'success': True,
            'email': email,
            'profile_exists': True,
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': UserProfileSerializer(profile).data,
        })


class ProfileSetupView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ProfileSetupSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = request.data.get('email', '').strip().lower()
        if not email:
            return Response({'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

        otp = OTP.objects.filter(email=email, is_verified=True).last()
        if not otp:
            return Response({'error': 'Email not verified. Please verify OTP first.'}, status=status.HTTP_400_BAD_REQUEST)

        user, created = User.objects.get_or_create(
            username=email,
            defaults={'email': email},
        )
        if created:
            user.set_unusable_password()
            user.save()

        role = serializer.validated_data['role']
        defaults = {
            'uid': email,
            'email': email,
            'name': serializer.validated_data['name'],
            'role': role,
            'phone': serializer.validated_data.get('phone', ''),
            'avatar_url': serializer.validated_data.get('avatar_url', ''),
        }
        if role == 'delivery_partner':
            defaults['is_available'] = False

        profile, _ = UserProfile.objects.get_or_create(
            user=user,
            defaults=defaults,
        )

        if not created:
            profile.name = serializer.validated_data['name']
            profile.role = serializer.validated_data['role']
            profile.phone = serializer.validated_data.get('phone', '')
            profile.avatar_url = serializer.validated_data.get('avatar_url', '')
            profile.save()

        if 'dietary_preferences' in serializer.validated_data:
            profile.dietary_preferences = serializer.validated_data['dietary_preferences']
        if 'allergies' in serializer.validated_data:
            profile.allergies = serializer.validated_data['allergies']
        profile.save()

        otp.delete()

        refresh = RefreshToken.for_user(user)
        access_token = str(refresh.access_token)
        refresh_token = str(refresh)

        return Response({
            'success': True,
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': UserProfileSerializer(profile).data,
        })


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh_token')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
        except Exception:
            pass
        return Response({'success': True})


class RefreshTokenView(TokenRefreshView):
    pass


# ──────────────────────────────────────────────
# USER / PROFILE VIEWS
# ──────────────────────────────────────────────

class UserProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user.profile


class UserProfileByUIDView(generics.RetrieveAPIView):
    serializer_class = UserProfileMiniSerializer
    permission_classes = [AllowAny]
    lookup_field = 'uid'
    queryset = UserProfile.objects.all()


class UpdateFCMTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get('fcm_token', '')
        profile = request.user.profile
        profile.fcm_token = token
        profile.save()
        return Response({'success': True})


class ToggleFavoriteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, kitchen_id):
        profile = request.user.profile
        favorites = list(profile.favorite_kitchen_ids)
        if kitchen_id in favorites:
            favorites.remove(kitchen_id)
        else:
            favorites.append(kitchen_id)
        profile.favorite_kitchen_ids = favorites
        profile.save()
        return Response({'favorite_kitchen_ids': favorites})


# ──────────────────────────────────────────────
# ADDRESS VIEWS
# ──────────────────────────────────────────────

class AddressListCreateView(generics.ListCreateAPIView):
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Address.objects.filter(user=self.request.user.profile)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user.profile)


class AddressDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = AddressSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Address.objects.filter(user=self.request.user.profile)


# ──────────────────────────────────────────────
# KITCHEN VIEWS
# ──────────────────────────────────────────────

class KitchenCategoryListView(generics.ListAPIView):
    queryset = KitchenCategory.objects.filter(is_active=True)
    serializer_class = KitchenCategorySerializer
    permission_classes = [AllowAny]


class KitchenListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return KitchenListSerializer
        return KitchenSerializer

    def get_queryset(self):
        qs = Kitchen.objects.all()
        if self.request.user.profile.role == 'chef':
            qs = qs.filter(chef=self.request.user.profile)
        elif self.request.user.profile.role != 'admin':
            qs = qs.filter(status='approved', is_open=True)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',') if s.strip()]
            if statuses:
                qs = qs.filter(status__in=statuses)
        category = self.request.query_params.get('category')
        if category and category != 'all':
            qs = qs.filter(categories_list__contains=category)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(name__icontains=search)
        is_veg = self.request.query_params.get('is_veg')
        if is_veg and is_veg.lower() in ['true', '1', 'yes']:
            qs = qs.filter(is_veg=True)
        min_rating = self.request.query_params.get('min_rating')
        if min_rating:
            try:
                qs = qs.filter(rating__gte=float(min_rating))
            except ValueError:
                pass
        return qs.order_by('name')

    def perform_create(self, serializer):
        status_val = 'approved' if self.request.user.profile.role == 'admin' else 'pending'
        kitchen = serializer.save(chef=self.request.user.profile, status=status_val)
        return kitchen


class KitchenDetailView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        return KitchenSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        if profile.role == 'admin':
            return Kitchen.objects.all()
        if profile.role == 'chef':
            return Kitchen.objects.filter(chef=profile)
        return Kitchen.objects.filter(status='approved', is_open=True)

    def perform_update(self, serializer):
        profile = self.request.user.profile
        kitchen = self.get_object()
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')
        serializer.save()


class KitchenStatusUpdateView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, pk):
        status_val = request.data.get('status')
        if status_val not in ['approved', 'rejected']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            kitchen = Kitchen.objects.get(pk=pk)
            kitchen.status = status_val
            kitchen.save()
            return Response(KitchenSerializer(kitchen).data)
        except Kitchen.DoesNotExist:
            return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)


class KitchenToggleOpenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        profile = request.user.profile
        try:
            if profile.role == 'admin':
                kitchen = Kitchen.objects.get(pk=pk)
            else:
                kitchen = Kitchen.objects.get(pk=pk, chef=profile)
            kitchen.is_open = not kitchen.is_open
            kitchen.save()
            return Response({'is_open': kitchen.is_open})
        except Kitchen.DoesNotExist:
            return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)


# ──────────────────────────────────────────────
# MENU / PLAN / DISH VIEWS
# ──────────────────────────────────────────────

class MenuCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = MenuCategorySerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        kitchen_id = self.kwargs.get('kitchen_pk')
        profile = self.request.user.profile
        if profile.role == 'chef':
            return MenuCategory.objects.filter(kitchen_id=kitchen_id, kitchen__chef=profile).order_by('sort_order')
        return MenuCategory.objects.filter(kitchen_id=kitchen_id).order_by('sort_order')

    def _get_kitchen(self):
        try:
            kitchen = Kitchen.objects.get(pk=self.kwargs['kitchen_pk'])
        except Kitchen.DoesNotExist:
            raise NotFound('Kitchen not found')
        profile = self.request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')
        return kitchen

    def perform_create(self, serializer):
        serializer.save(kitchen=self._get_kitchen())

    def perform_update(self, serializer):
        self._get_kitchen()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_kitchen()
        instance.delete()


class MenuItemViewSet(viewsets.ModelViewSet):
    serializer_class = MenuItemSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        kitchen_id = self.kwargs.get('kitchen_pk')
        profile = self.request.user.profile
        if profile.role == 'chef':
            return MenuItem.objects.filter(kitchen_id=kitchen_id, kitchen__chef=profile)
        return MenuItem.objects.filter(kitchen_id=kitchen_id)

    def _get_kitchen(self):
        try:
            kitchen = Kitchen.objects.get(pk=self.kwargs['kitchen_pk'])
        except Kitchen.DoesNotExist:
            raise NotFound('Kitchen not found')
        profile = self.request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')
        return kitchen

    def perform_create(self, serializer):
        serializer.save(kitchen=self._get_kitchen())

    def perform_update(self, serializer):
        self._get_kitchen()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_kitchen()
        instance.delete()


class SubscriptionPlanViewSet(viewsets.ModelViewSet):
    serializer_class = SubscriptionPlanSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        kitchen_id = self.kwargs.get('kitchen_pk')
        profile = self.request.user.profile
        if profile.role == 'chef':
            return SubscriptionPlan.objects.filter(kitchen_id=kitchen_id, kitchen__chef=profile)
        return SubscriptionPlan.objects.filter(kitchen_id=kitchen_id)

    def _get_kitchen(self):
        try:
            kitchen = Kitchen.objects.get(pk=self.kwargs['kitchen_pk'])
        except Kitchen.DoesNotExist:
            raise NotFound('Kitchen not found')
        profile = self.request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')
        return kitchen

    def perform_create(self, serializer):
        serializer.save(kitchen=self._get_kitchen())

    def perform_update(self, serializer):
        self._get_kitchen()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_kitchen()
        instance.delete()


class DailyMenuListCreateView(generics.ListCreateAPIView):
    serializer_class = DailyMenuSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        kitchen_id = self.kwargs.get('kitchen_pk')
        profile = self.request.user.profile
        if profile.role == 'chef':
            qs = DailyMenu.objects.filter(kitchen_id=kitchen_id, kitchen__chef=profile)
        else:
            qs = DailyMenu.objects.filter(kitchen_id=kitchen_id)
        start = self.request.query_params.get('start_date')
        end = self.request.query_params.get('end_date')
        if start:
            qs = qs.filter(date__gte=start)
        if end:
            qs = qs.filter(date__lte=end)
        return qs

    def perform_create(self, serializer):
        try:
            kitchen = Kitchen.objects.get(pk=self.kwargs['kitchen_pk'])
        except Kitchen.DoesNotExist:
            raise NotFound('Kitchen not found')
        profile = self.request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')
        serializer.save(kitchen=kitchen)


class DailyMenuDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DailyMenuSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        kitchen_id = self.kwargs['kitchen_pk']
        profile = self.request.user.profile
        if profile.role == 'admin':
            return DailyMenu.objects.filter(kitchen_id=kitchen_id)
        return DailyMenu.objects.filter(kitchen_id=kitchen_id, kitchen__chef=profile)

    def perform_update(self, serializer):
        self._check_kitchen_owner()
        serializer.save()

    def perform_destroy(self, instance):
        self._check_kitchen_owner()
        instance.delete()

    def _check_kitchen_owner(self):
        try:
            kitchen = Kitchen.objects.get(pk=self.kwargs['kitchen_pk'])
        except Kitchen.DoesNotExist:
            raise NotFound('Kitchen not found')
        profile = self.request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            raise PermissionDenied('You do not own this kitchen')


# ──────────────────────────────────────────────
# ORDER VIEWS
# ──────────────────────────────────────────────

class OrderListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return OrderCreateSerializer
        return OrderSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        qs = Order.objects.all()
        if profile.role == 'customer':
            qs = qs.filter(customer=profile)
        elif profile.role == 'chef':
            qs = qs.filter(kitchen__chef=profile)
        elif profile.role == 'delivery_partner':
            qs = qs.filter(delivery_partner=profile)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        delivery_status = self.request.query_params.get('delivery_status')
        if delivery_status:
            qs = qs.filter(delivery_status=delivery_status)
        kitchen_id = self.request.query_params.get('kitchen_id')
        if kitchen_id:
            qs = qs.filter(kitchen_id=kitchen_id)
        return qs.order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(customer=self.request.user.profile)


class OrderDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = self.request.user.profile
        if profile.role == 'admin':
            return Order.objects.all()
        if profile.role == 'customer':
            return Order.objects.filter(customer=profile)
        if profile.role == 'chef':
            return Order.objects.filter(kitchen__chef=profile)
        if profile.role == 'delivery_partner':
            return Order.objects.filter(delivery_partner=profile)
        return Order.objects.none()


class OrderStatusUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    DELIVERY_STATUS_MAP = {
        'Preparing': 'ready_for_delivery',
        'preparing': 'ready_for_delivery',
        'Out for Delivery': 'picked_up',
        'out for delivery': 'picked_up',
        'Delivered': 'delivered',
        'delivered': 'delivered',
    }

    def post(self, request, pk):
        new_status = request.data.get('status')
        profile = request.user.profile
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        if profile.role != 'admin' and order.customer != profile and order.kitchen.chef != profile:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        if new_status in self.DELIVERY_STATUS_MAP:
            order.delivery_status = self.DELIVERY_STATUS_MAP[new_status]
            if order.delivery_status == 'delivered':
                order.delivered_at = timezone.now()
            elif order.delivery_status == 'picked_up':
                order.picked_up_at = order.picked_up_at or timezone.now()
            order.save()
            return Response(OrderSerializer(order).data)

        if new_status not in ['active', 'paused', 'cancelled', 'completed']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        order.status = new_status
        if new_status == 'paused':
            order.is_paused = True
        elif new_status in ('active', 'cancelled', 'completed'):
            order.is_paused = False
        order.save()
        return Response(OrderSerializer(order).data)


# ──────────────────────────────────────────────
# DELIVERY VIEWS
# ──────────────────────────────────────────────

class AvailableDeliveriesView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsDeliveryPartner]

    def get_queryset(self):
        if not self.request.user.profile.is_verified:
            return Order.objects.none()
        return Order.objects.filter(
            delivery_status='ready_for_delivery',
            delivery_partner__isnull=True,
        ).order_by('-created_at')


class AcceptDeliveryView(APIView):
    permission_classes = [IsDeliveryPartner]

    def post(self, request, pk):
        if not request.user.profile.is_verified:
            return Response({'error': 'Your documents are not verified yet. Please wait for admin approval.'}, status=status.HTTP_403_FORBIDDEN)
        try:
            with transaction.atomic():
                order = Order.objects.select_for_update().get(
                    pk=pk, delivery_status='ready_for_delivery', delivery_partner__isnull=True
                )
                order.delivery_partner = request.user.profile
                order.delivery_status = 'assigned'
                order.assigned_at = timezone.now()
                order.delivery_fee = order.delivery_fee or Decimal('30.00')
                order.save()
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not available'}, status=status.HTTP_400_BAD_REQUEST)


class MyDeliveriesView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsDeliveryPartner]

    def get_queryset(self):
        return Order.objects.filter(
            delivery_partner=self.request.user.profile
        ).exclude(
            delivery_status__in=['delivered', 'cancelled']
        ).order_by('-assigned_at', '-id')


class MyDeliveryHistoryView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsDeliveryPartner]

    def get_queryset(self):
        return Order.objects.filter(
            delivery_partner=self.request.user.profile,
            delivery_status='delivered',
        ).order_by('-delivered_at')


class UpdateDeliveryStatusView(APIView):
    permission_classes = [IsDeliveryPartner]

    VALID_TRANSITIONS = {
        'assigned': ['picked_up'],
        'picked_up': ['delivered'],
    }

    def post(self, request, pk):
        new_status = request.data.get('delivery_status')
        otp_code = request.data.get('otp')

        if new_status not in ['picked_up', 'delivered']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == 'delivered' and not otp_code:
            return Response({'error': 'OTP is required for delivery confirmation'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=pk, delivery_partner=request.user.profile)
            allowed = self.VALID_TRANSITIONS.get(order.delivery_status, [])
            if new_status not in allowed:
                return Response(
                    {'error': f'Cannot transition from {order.delivery_status} to {new_status}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if new_status == 'delivered' and otp_code:
                stored_otp = getattr(order, 'delivery_otp', None)
                if stored_otp and stored_otp.strip() != otp_code.strip():
                    return Response({'error': 'Invalid OTP. Please check the code and try again.'}, status=status.HTTP_400_BAD_REQUEST)

            order.delivery_status = new_status
            if new_status == 'picked_up':
                order.picked_up_at = timezone.now()
            elif new_status == 'delivered':
                order.delivered_at = timezone.now()
            order.save()
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)


class GenerateDeliveryOTPView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        if order.customer != request.user.profile:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        import random
        otp = f'{random.randint(100000, 999999)}'
        order.delivery_otp = otp
        order.save(update_fields=['delivery_otp'])

        return Response({
            'message': 'OTP generated',
            'otp': otp,
            'hint': f'Your delivery OTP is {otp}',
        })


class VerifyDeliveryOTPView(APIView):
    permission_classes = [IsDeliveryPartner]

    def post(self, request, pk):
        otp_code = request.data.get('otp', '').strip()
        if not otp_code:
            return Response({'error': 'OTP is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=pk, delivery_partner=request.user.profile)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        stored_otp = getattr(order, 'delivery_otp', None)
        if not stored_otp:
            return Response({'error': 'No OTP generated for this delivery'}, status=status.HTTP_400_BAD_REQUEST)

        if stored_otp.strip() != otp_code:
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

        order.delivery_status = 'delivered'
        order.delivered_at = timezone.now()
        order.save()

        return Response(OrderSerializer(order).data)


class DeliveryEarningsView(APIView):
    permission_classes = [IsDeliveryPartner]

    def get(self, request):
        profile = request.user.profile
        delivered = Order.objects.filter(
            delivery_partner=profile,
            delivery_status='delivered',
        )
        total = delivered.aggregate(total=Sum('delivery_fee'))['total'] or 0
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start = today_start - timedelta(days=today_start.weekday())
        today = delivered.filter(
            delivered_at__isnull=False,
            delivered_at__gte=today_start,
        ).aggregate(t=Sum('delivery_fee'))['t'] or 0
        week = delivered.filter(
            delivered_at__isnull=False,
            delivered_at__gte=week_start,
        ).aggregate(t=Sum('delivery_fee'))['t'] or 0
        total_deliveries = delivered.count()

        return Response({
            'total_earnings': float(total),
            'today_earnings': float(today),
            'weekly_earnings': float(week),
            'total_deliveries': total_deliveries,
        })


class DeliveryAvailabilityView(APIView):
    permission_classes = [IsDeliveryPartner]

    def get(self, request):
        profile = request.user.profile
        return Response({
            'is_available': profile.is_available,
            'is_verified': profile.is_verified,
        })

    def post(self, request):
        profile = request.user.profile
        is_available = request.data.get('is_available')
        if is_available is None:
            return Response({'error': 'is_available is required'}, status=status.HTTP_400_BAD_REQUEST)
        if is_available is True and not profile.is_verified:
            return Response({'error': 'Documents not verified. Please wait for admin approval.'}, status=status.HTTP_403_FORBIDDEN)
        profile.is_available = bool(is_available) if is_available is not None else False
        profile.save(update_fields=['is_available'])
        return Response({'is_available': profile.is_available})


# ──────────────────────────────────────────────
# DELIVERY DOCUMENT VERIFICATION VIEWS
# ──────────────────────────────────────────────


class DeliveryDocumentListView(generics.ListAPIView):
    serializer_class = DeliveryDocumentSerializer
    permission_classes = [IsDeliveryPartner]

    def get_queryset(self):
        return DeliveryDocument.objects.filter(user=self.request.user.profile).order_by('doc_type')


class DeliveryDocumentUploadView(APIView):
    permission_classes = [IsDeliveryPartner]

    def post(self, request):
        doc_type = request.data.get('doc_type')
        doc_number = request.data.get('doc_number', '')
        file_url = request.data.get('file_url', '')

        if doc_type not in ['aadhar', 'pan', 'driving_license']:
            return Response({'error': 'Invalid document type'}, status=status.HTTP_400_BAD_REQUEST)
        if not file_url and not doc_number:
            return Response({'error': 'Either file_url or doc_number is required'}, status=status.HTTP_400_BAD_REQUEST)

        profile = request.user.profile
        doc, created = DeliveryDocument.objects.update_or_create(
            user=profile,
            doc_type=doc_type,
            defaults={
                'doc_number': doc_number,
                'file_url': file_url,
                'status': 'pending',
                'verification_notes': '',
            },
        )
        return Response(DeliveryDocumentSerializer(doc).data, status=status.HTTP_200_OK if not created else status.HTTP_201_CREATED)


class DeliveryDocumentDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = DeliveryDocumentSerializer
    permission_classes = [IsDeliveryPartner]

    def get_queryset(self):
        return DeliveryDocument.objects.filter(user=self.request.user.profile)


class DeliveryDocumentDeleteView(APIView):
    permission_classes = [IsDeliveryPartner]

    def delete(self, request, pk):
        try:
            doc = DeliveryDocument.objects.get(pk=pk, user=request.user.profile)
            doc.delete()
            return Response({'success': True})
        except DeliveryDocument.DoesNotExist:
            return Response({'error': 'Document not found'}, status=status.HTTP_404_NOT_FOUND)


# ──────────────────────────────────────────────
# ADMIN: DELIVERY PARTNER DOCUMENT VERIFICATION
# ──────────────────────────────────────────────


class AdminDeliveryPartnersView(generics.ListAPIView):
    serializer_class = AdminDeliveryPartnerSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = UserProfile.objects.filter(role='delivery_partner').order_by('-created_at')
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(email__icontains=search))
        verified = self.request.query_params.get('verified')
        if verified == 'true':
            qs = qs.filter(is_verified=True)
        elif verified == 'false':
            qs = qs.filter(is_verified=False)
        return qs


class AdminDeliveryDocumentListView(generics.ListAPIView):
    serializer_class = AdminDeliveryDocumentSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        user_uid = self.request.query_params.get('user_uid')
        qs = DeliveryDocument.objects.all().order_by('user', 'doc_type')
        if user_uid:
            qs = qs.filter(user__uid=user_uid)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class AdminDeliveryDocumentUpdateView(APIView):
    permission_classes = [IsAdmin]

    def put(self, request, pk):
        try:
            doc = DeliveryDocument.objects.get(pk=pk)
        except DeliveryDocument.DoesNotExist:
            return Response({'error': 'Document not found'}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        if new_status not in ['pending', 'verified', 'rejected']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)

        doc.status = new_status
        doc.verification_notes = request.data.get('verification_notes', '')
        doc.save()

        # Auto-set is_verified on profile when all required docs are verified
        if new_status == 'verified':
            profile = doc.user
            required_docs = ['aadhar', 'pan']
            all_verified = all(
                DeliveryDocument.objects.filter(user=profile, doc_type=dt, status='verified').exists()
                for dt in required_docs
            )
            if all_verified:
                profile.is_verified = True
                profile.save(update_fields=['is_verified'])
        elif new_status == 'rejected':
            profile = doc.user
            if profile.is_verified:
                profile.is_verified = False
                profile.save(update_fields=['is_verified'])

        return Response(AdminDeliveryDocumentSerializer(doc).data)


# ──────────────────────────────────────────────
# DELIVERY LOG VIEWS
# ──────────────────────────────────────────────

class DeliveryLogListView(generics.ListAPIView):
    serializer_class = DeliveryLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        order_id = self.kwargs.get('order_id')
        try:
            order = Order.objects.get(pk=order_id)
        except Order.DoesNotExist:
            return DeliveryLog.objects.none()
        profile = self.request.user.profile
        if not (profile.role == 'admin' or order.customer == profile or order.kitchen.chef == profile or order.delivery_partner == profile):
            return DeliveryLog.objects.none()
        return DeliveryLog.objects.filter(order_id=order_id).order_by('-date')


class CreateDeliveryLogView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = request.user.profile
        qs = DeliveryLog.objects.all()
        if profile.role == 'chef':
            qs = qs.filter(order__kitchen__chef=profile)
        elif profile.role == 'delivery_partner':
            qs = qs.filter(delivered_by=profile)
        elif profile.role == 'customer':
            qs = qs.filter(order__customer=profile)
        status_filter = request.query_params.get('status')
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',') if s.strip()]
            if statuses:
                qs = qs.filter(status__in=statuses)
        qs = qs.order_by('-date', '-id')
        return Response(DeliveryLogSerializer(qs, many=True).data)

    def post(self, request):
        order_id = request.data.get('order')
        if not order_id:
            return Response({'error': 'order is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            order = Order.objects.get(pk=order_id)
            profile = request.user.profile
            if profile.role not in ['admin', 'delivery_partner'] and order.customer != profile and order.kitchen.chef != profile:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        serializer = DeliveryLogSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        log = serializer.save(delivered_by=profile)
        return Response(DeliveryLogSerializer(log).data, status=status.HTTP_201_CREATED)


class SubmitDailyFeedbackView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        order_id = request.data.get('order_id')
        date = request.data.get('date')
        rating_raw = request.data.get('rating')
        feedback = request.data.get('feedback', '')

        if not all([order_id, date, rating_raw is not None]):
            return Response({'error': 'order_id, date, and rating are required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            rating = float(rating_raw)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid rating value'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=order_id)
            profile = request.user.profile
            if profile.role != 'admin' and order.customer != profile and order.kitchen.chef != profile:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        log, _ = DeliveryLog.objects.get_or_create(
            order_id=order_id,
            date=date,
            defaults={'status': 'delivered'},
        )
        log.rating = rating
        log.feedback = feedback
        log.save()
        return Response(DeliveryLogSerializer(log).data)


# ──────────────────────────────────────────────
# SKIP / CANCEL TRANSACTION VIEWS
# ──────────────────────────────────────────────

class SkipMealView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        order_id = request.data.get('order_id')
        date = request.data.get('date')

        if not order_id or not date:
            return Response({'error': 'order_id and date required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=order_id, customer=request.user.profile)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        skip_limit = timezone.make_aware(
            timezone.datetime.strptime(date, '%Y-%m-%d').replace(hour=2),
            timezone.get_current_timezone(),
        )
        if timezone.now() > skip_limit:
            return Response({'error': 'Cut-off time passed (2 hours before delivery)'}, status=status.HTTP_400_BAD_REQUEST)

        duration = (order.end_date - order.start_date).days or 1
        daily_rate = Decimal(str(order.amount)) / duration

        with transaction.atomic():
            DeliveryLog.objects.create(
                order=order,
                date=date,
                status='skipped',
                refund_amount=float(daily_rate),
            )
            profile = request.user.profile
            profile.wallet_balance += daily_rate
            profile.save()
            WalletTransaction.objects.create(
                user=profile,
                amount=daily_rate,
                type='credit',
                category='refund',
                description=f'Refund for skipped meal ({order.kitchen.name})',
            )

        return Response({'success': True, 'refund_amount': daily_rate})


class CancelSubscriptionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        order_id = request.data.get('order_id')
        if not order_id:
            return Response({'error': 'order_id required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=order_id, customer=request.user.profile)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)

        if order.status == 'cancelled':
            return Response({'error': 'Already cancelled'}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now().date()
        if now > order.end_date:
            return Response({'error': 'Subscription has ended'}, status=status.HTTP_400_BAD_REQUEST)

        effective_now = max(now, order.start_date)
        total_days = (order.end_date - order.start_date).days or 1
        remaining_days = max(0, (order.end_date - effective_now).days)
        daily_rate = Decimal(str(order.amount)) / Decimal(str(total_days))
        refund_amount = daily_rate * Decimal(str(remaining_days))

        with transaction.atomic():
            order.status = 'cancelled'
            order.save()
            profile = request.user.profile
            profile.wallet_balance += refund_amount
            profile.save()
            WalletTransaction.objects.create(
                user=profile,
                amount=refund_amount,
                type='credit',
                category='refund',
                description=f'Refund for cancelled subscription ({order.kitchen.name})',
            )

        return Response({'success': True, 'refund_amount': refund_amount})


# ──────────────────────────────────────────────
# PAYMENT VIEWS
# ──────────────────────────────────────────────

class PlaceOrderView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        kitchen_id = request.data.get('kitchen')
        if kitchen_id:
            try:
                kitchen = Kitchen.objects.get(pk=kitchen_id)
                if kitchen.status != 'approved':
                    return Response({'error': 'Kitchen is not approved'}, status=status.HTTP_400_BAD_REQUEST)
                if not kitchen.is_open:
                    return Response({'error': 'Kitchen is currently closed'}, status=status.HTTP_400_BAD_REQUEST)
            except Kitchen.DoesNotExist:
                return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = OrderCreateSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plan_id = request.data.get('plan')
        if plan_id:
            try:
                plan = SubscriptionPlan.objects.get(pk=plan_id)
                if Decimal(str(serializer.validated_data.get('amount', 0))) != plan.price:
                    return Response({'error': 'Amount does not match plan price'}, status=status.HTTP_400_BAD_REQUEST)
                start = serializer.validated_data.get('start_date')
                end = serializer.validated_data.get('end_date')
                if start and end and (end - start).days != plan.duration_days:
                    return Response({'error': f'Subscription period must be {plan.duration_days} days'}, status=status.HTTP_400_BAD_REQUEST)
            except SubscriptionPlan.DoesNotExist:
                return Response({'error': 'Plan not found'}, status=status.HTTP_404_NOT_FOUND)

        order = serializer.save()
        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class PlaceOrderWithWalletView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        kitchen_id = request.data.get('kitchen')
        if kitchen_id:
            try:
                kitchen = Kitchen.objects.get(pk=kitchen_id)
                if kitchen.status != 'approved':
                    return Response({'error': 'Kitchen is not approved'}, status=status.HTTP_400_BAD_REQUEST)
                if not kitchen.is_open:
                    return Response({'error': 'Kitchen is currently closed'}, status=status.HTTP_400_BAD_REQUEST)
            except Kitchen.DoesNotExist:
                return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = OrderCreateSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        plan_id = request.data.get('plan')
        if plan_id:
            try:
                plan = SubscriptionPlan.objects.get(pk=plan_id)
                if Decimal(str(serializer.validated_data.get('amount', 0))) != plan.price:
                    return Response({'error': 'Amount does not match plan price'}, status=status.HTTP_400_BAD_REQUEST)
                start = serializer.validated_data.get('start_date')
                end = serializer.validated_data.get('end_date')
                if start and end and (end - start).days != plan.duration_days:
                    return Response({'error': f'Subscription period must be {plan.duration_days} days'}, status=status.HTTP_400_BAD_REQUEST)
            except SubscriptionPlan.DoesNotExist:
                return Response({'error': 'Plan not found'}, status=status.HTTP_404_NOT_FOUND)

        raw_deduction = request.data.get('wallet_deduction')
        wallet_deduction = Decimal(str(raw_deduction)) if raw_deduction else Decimal('0')
        profile = UserProfile.objects.select_for_update().get(pk=request.user.profile.pk)

        if wallet_deduction > profile.wallet_balance:
            return Response({'error': 'Insufficient wallet balance'}, status=status.HTTP_400_BAD_REQUEST)

        order = serializer.save()
        profile.wallet_balance -= wallet_deduction
        profile.save()

        WalletTransaction.objects.create(
            user=profile,
            amount=wallet_deduction,
            type='debit',
            category='order_payment',
            description=f'Used credits for subscription to {order.kitchen.name}',
        )

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class PaymentSuccessView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        payment_id = request.data.get('payment_id')
        order_id = request.data.get('order_id')
        if not payment_id or not order_id:
            return Response({'error': 'payment_id and order_id required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order = Order.objects.get(pk=order_id, customer=request.user.profile)
            if order.payment_id:
                return Response({'error': 'Order already paid'}, status=status.HTTP_400_BAD_REQUEST)
            order.payment_id = payment_id
            order.status = 'active'
            order.save()
            Payment.objects.create(
                order=order,
                user=request.user.profile,
                amount=order.amount,
                payment_id=payment_id,
                status='completed',
            )
            return Response(OrderSerializer(order).data)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)


# ──────────────────────────────────────────────
# WALLET VIEWS
# ──────────────────────────────────────────────

class WalletView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = request.user.profile
        transactions = WalletTransaction.objects.filter(user=profile)[:50]
        return Response({
            'wallet_balance': float(profile.wallet_balance),
            'transactions': WalletTransactionSerializer(transactions, many=True).data,
        })


# ──────────────────────────────────────────────
# REVIEW VIEWS
# ──────────────────────────────────────────────

class KitchenReviewListView(generics.ListAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        kitchen_id = self.kwargs.get('kitchen_pk')
        return Review.objects.filter(kitchen_id=kitchen_id).order_by('-created_at')


class CreateReviewView(generics.CreateAPIView):
    serializer_class = ReviewCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        review = serializer.save()
        kitchen = review.kitchen
        stats = Review.objects.filter(kitchen=kitchen).aggregate(
            avg_rating=Avg('rating'),
            total=Count('id'),
        )
        kitchen.rating = round(stats['avg_rating'] or 0.0, 1)
        kitchen.total_ratings = stats['total'] or 0
        kitchen.save()


# ──────────────────────────────────────────────
# COUPON VIEWS
# ──────────────────────────────────────────────

class CouponValidateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CouponValidateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        code = serializer.validated_data['code'].upper()
        order_amount = serializer.validated_data['order_amount']

        try:
            coupon = Coupon.objects.get(code=code, is_active=True)
        except Coupon.DoesNotExist:
            return Response({'error': 'Invalid coupon code'}, status=status.HTTP_404_NOT_FOUND)

        if coupon.expiry_date < timezone.now():
            return Response({'error': 'Coupon has expired'}, status=status.HTTP_400_BAD_REQUEST)

        if order_amount < coupon.min_order_value:
            return Response(
                {'error': f'Minimum order value of {coupon.min_order_value} required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if coupon.usage_limit > 0 and coupon.used_count >= coupon.usage_limit:
            return Response({'error': 'Coupon usage limit reached'}, status=status.HTTP_400_BAD_REQUEST)

        if coupon.discount_type == 'flat':
            discount = float(coupon.discount_value)
        else:
            discount = float(order_amount) * float(coupon.discount_value) / 100
            if coupon.max_discount:
                discount = min(discount, float(coupon.max_discount))

        return Response(CouponSerializer(coupon).data | {'discount_amount': discount})


class CouponListCreateView(generics.ListCreateAPIView):
    queryset = Coupon.objects.all().order_by('-created_at')
    serializer_class = CouponSerializer
    permission_classes = [IsAdmin]


class CouponDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Coupon.objects.all()
    serializer_class = CouponSerializer
    permission_classes = [IsAdmin]


# ──────────────────────────────────────────────
# NOTIFICATION VIEWS
# ──────────────────────────────────────────────

class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user.profile).order_by('-created_at')


class MarkNotificationReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            notification = Notification.objects.get(pk=pk, user=request.user.profile)
            notification.is_read = True
            notification.save()
            return Response({'success': True})
        except Notification.DoesNotExist:
            return Response({'error': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)


class MarkAllNotificationsReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(user=request.user.profile, is_read=False).update(is_read=True)
        return Response({'success': True})


class UnreadNotificationCountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(user=request.user.profile, is_read=False).count()
        return Response({'unread_count': count})


# ──────────────────────────────────────────────
# SUPPORT TICKET VIEWS
# ──────────────────────────────────────────────

class SupportTicketListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return SupportTicketCreateSerializer
        return SupportTicketSerializer

    def get_queryset(self):
        profile = self.request.user.profile
        if profile.role == 'admin':
            return SupportTicket.objects.all().order_by('-created_at')
        return SupportTicket.objects.filter(user=profile).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user.profile)


class SupportTicketDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = SupportTicketSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        return SupportTicket.objects.all()


# ──────────────────────────────────────────────
# CHAT VIEWS
# ──────────────────────────────────────────────

class ChatMessageListView(generics.ListAPIView):
    serializer_class = ChatMessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = self.request.user.profile
        other_uid = self.request.query_params.get('other_uid')
        kitchen_id = self.request.query_params.get('kitchen_id')
        qs = ChatMessage.objects.filter(
            Q(sender=profile) | Q(receiver=profile)
        )
        if other_uid:
            qs = qs.filter(
                Q(sender__uid=other_uid) | Q(receiver__uid=other_uid)
            )
        if kitchen_id:
            qs = qs.filter(kitchen_id=kitchen_id)
        return qs.order_by('created_at')


class SendChatMessageView(generics.CreateAPIView):
    serializer_class = ChatMessageCreateSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user.profile)


class MarkChatReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        other_uid = request.data.get('other_uid')
        if not other_uid:
            return Response({'error': 'other_uid required'}, status=status.HTTP_400_BAD_REQUEST)
        ChatMessage.objects.filter(
            receiver=request.user.profile,
            sender__uid=other_uid,
            is_read=False,
        ).update(is_read=True)
        return Response({'success': True})


class ChatContactsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = request.user.profile
        sent_uids = ChatMessage.objects.filter(sender=profile).values_list('receiver', flat=True).distinct()
        received_uids = ChatMessage.objects.filter(receiver=profile).values_list('sender', flat=True).distinct()
        all_uids = set(sent_uids) | set(received_uids)
        contacts = UserProfile.objects.filter(id__in=all_uids)
        return Response(UserProfileMiniSerializer(contacts, many=True).data)


# ──────────────────────────────────────────────
# ADMIN VIEWS
# ──────────────────────────────────────────────

class AdminDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        total_users = UserProfile.objects.count()
        total_chefs = UserProfile.objects.filter(role='chef').count()
        total_customers = UserProfile.objects.filter(role='customer').count()
        total_delivery_partners = UserProfile.objects.filter(role='delivery_partner').count()
        total_kitchens = Kitchen.objects.count()
        pending_kitchens = Kitchen.objects.filter(status='pending').count()
        total_orders = Order.objects.count()
        active_orders = Order.objects.filter(status='active').count()
        total_revenue = Order.objects.filter(status__in=['active', 'completed']).aggregate(t=Sum('amount'))['t'] or 0
        total_payouts = PayoutRequest.objects.filter(status='paid').aggregate(t=Sum('amount'))['t'] or 0

        return Response({
            'total_users': total_users,
            'total_chefs': total_chefs,
            'total_customers': total_customers,
            'total_delivery_partners': total_delivery_partners,
            'total_kitchens': total_kitchens,
            'pending_kitchens': pending_kitchens,
            'total_orders': total_orders,
            'active_orders': active_orders,
            'total_revenue': float(total_revenue),
            'total_payouts': float(total_payouts),
        })


class AdminUserListView(generics.ListAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = UserProfile.objects.all().order_by('-created_at')
        role = self.request.query_params.get('role')
        if role:
            qs = qs.filter(role=role)
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(email__icontains=search))
        return qs


class AdminUserDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAdmin]
    queryset = UserProfile.objects.all()
    lookup_field = 'uid'


class AdminKitchenListView(generics.ListAPIView):
    serializer_class = KitchenListSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = Kitchen.objects.all().order_by('-created_at')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',') if s.strip()]
            if statuses:
                qs = qs.filter(status__in=statuses)
        return qs


class AdminOrderListView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = Order.objects.all().order_by('-created_at')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',') if s.strip()]
            if statuses:
                qs = qs.filter(status__in=statuses)
        return qs


class AdminPayoutListView(generics.ListAPIView):
    serializer_class = PayoutRequestSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = PayoutRequest.objects.all().order_by('-requested_at')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            statuses = [s.strip() for s in status_filter.split(',') if s.strip()]
            if statuses:
                qs = qs.filter(status__in=statuses)
        return qs


class AdminPayoutUpdateView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, pk):
        new_status = request.data.get('status')
        if new_status not in ['approved', 'rejected', 'paid']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            payout = PayoutRequest.objects.get(pk=pk)
            payout.status = new_status
            if new_status in ['approved', 'paid']:
                payout.processed_at = timezone.now()
            payout.save()
            return Response(PayoutRequestSerializer(payout).data)
        except PayoutRequest.DoesNotExist:
            return Response({'error': 'Payout not found'}, status=status.HTTP_404_NOT_FOUND)


# ──────────────────────────────────────────────
# BANNER VIEWS
# ──────────────────────────────────────────────

class BannerListCreateView(generics.ListCreateAPIView):
    queryset = Banner.objects.filter(is_active=True).order_by('sort_order')
    serializer_class = BannerSerializer

    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdmin()]


class BannerDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Banner.objects.all()
    serializer_class = BannerSerializer
    permission_classes = [IsAdmin]


# ──────────────────────────────────────────────
# ADMIN SETTINGS VIEWS
# ──────────────────────────────────────────────

class AdminSettingListView(generics.ListCreateAPIView):
    queryset = AdminSetting.objects.all()
    serializer_class = AdminSettingSerializer
    permission_classes = [IsAdmin]


class AdminSettingDetailView(generics.RetrieveUpdateAPIView):
    queryset = AdminSetting.objects.all()
    serializer_class = AdminSettingSerializer
    permission_classes = [IsAdmin]


# ──────────────────────────────────────────────
# PAYOUT VIEWS (Chef)
# ──────────────────────────────────────────────

class ChefPayoutListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsChef]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return PayoutRequestCreateSerializer
        return PayoutRequestSerializer

    def get_queryset(self):
        return PayoutRequest.objects.filter(chef=self.request.user.profile).order_by('-requested_at')

    def perform_create(self, serializer):
        serializer.save(chef=self.request.user.profile)


# ──────────────────────────────────────────────
# KITCHEN IMAGE VIEWS
# ──────────────────────────────────────────────

class FileUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        file = request.FILES.get('file')
        if not file:
            return Response({'error': 'No file provided'}, status=status.HTTP_400_BAD_REQUEST)
        ext = os.path.splitext(file.name)[1] if '.' in file.name else '.jpg'
        filename = f'{uuid.uuid4().hex}{ext}'
        upload_dir = os.path.join(settings.MEDIA_ROOT, 'uploads')
        os.makedirs(upload_dir, exist_ok=True)
        filepath = os.path.join(upload_dir, filename)
        with open(filepath, 'wb+') as dest:
            for chunk in file.chunks():
                dest.write(chunk)
        url = f'{settings.MEDIA_URL}uploads/{filename}'
        return Response({'image_url': url, 'url': url}, status=status.HTTP_201_CREATED)


class KitchenImageUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, kitchen_pk):
        image_url = request.data.get('image_url')
        is_primary = request.data.get('is_primary', False)
        if not image_url:
            return Response({'error': 'image_url required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            kitchen = Kitchen.objects.get(pk=kitchen_pk)
        except Kitchen.DoesNotExist:
            return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)
        profile = request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        KitchenImage.objects.create(kitchen=kitchen, image_url=image_url, is_primary=is_primary)
        gallery = list(kitchen.gallery_images)
        gallery.append(image_url)
        kitchen.gallery_images = gallery
        kitchen.save()
        return Response({'success': True})


class KitchenImageDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, kitchen_pk):
        image_url = request.data.get('image_url')
        if not image_url:
            return Response({'error': 'image_url required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            kitchen = Kitchen.objects.get(pk=kitchen_pk)
        except Kitchen.DoesNotExist:
            return Response({'error': 'Kitchen not found'}, status=status.HTTP_404_NOT_FOUND)
        profile = request.user.profile
        if profile.role != 'admin' and kitchen.chef != profile:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        KitchenImage.objects.filter(kitchen=kitchen, image_url=image_url).delete()
        gallery = list(kitchen.gallery_images)
        if image_url in gallery:
            gallery.remove(image_url)
        kitchen.gallery_images = gallery
        kitchen.save()
        return Response({'success': True})


class MapRouteView(APIView):
    permission_classes = [IsAuthenticated]

    OSRM_BASE = 'https://router.project-osrm.org/route/v1/driving'

    def get(self, request):
        start_lat = request.query_params.get('start_lat')
        start_lng = request.query_params.get('start_lng')
        end_lat = request.query_params.get('end_lat')
        end_lng = request.query_params.get('end_lng')

        errors = []
        if not start_lat:
            errors.append('start_lat is required')
        if not start_lng:
            errors.append('start_lng is required')
        if not end_lat:
            errors.append('end_lat is required')
        if not end_lng:
            errors.append('end_lng is required')
        if errors:
            return Response({'error': '; '.join(errors)}, status=status.HTTP_400_BAD_REQUEST)

        try:
            start_lat_f = float(start_lat)
            start_lng_f = float(start_lng)
            end_lat_f = float(end_lat)
            end_lng_f = float(end_lng)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid coordinate values'}, status=status.HTTP_400_BAD_REQUEST)

        osrm_url = (
            f'{self.OSRM_BASE}/{start_lng_f},{start_lat_f};{end_lng_f},{end_lat_f}'
            f'?overview=full&geometries=geojson'
        )

        try:
            resp = requests.get(osrm_url, timeout=10)
            resp.raise_for_status()
            data = resp.json()
        except requests.ConnectionError:
            return Response({'error': 'Unable to reach routing service'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except requests.Timeout:
            return Response({'error': 'Routing service timed out'}, status=status.HTTP_504_GATEWAY_TIMEOUT)
        except requests.RequestException as e:
            return Response({'error': f'Routing request failed: {str(e)}'}, status=status.HTTP_502_BAD_GATEWAY)

        if data.get('code') != 'Ok' or not data.get('routes'):
            return Response({'error': 'No route found between the given points'}, status=status.HTTP_404_NOT_FOUND)

        route = data['routes'][0]
        distance_km = round(route['distance'] / 1000, 2)
        duration_min = round(route['duration'] / 60, 1)
        coordinates = route['geometry']['coordinates']

        return Response({
            'distance': distance_km,
            'duration': duration_min,
            'route': [[lat, lng] for lng, lat in coordinates],
        })
