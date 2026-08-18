from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'kitchens/(?P<kitchen_pk>[^/.]+)/menu-categories', views.MenuCategoryViewSet, basename='menu-category')
router.register(r'kitchens/(?P<kitchen_pk>[^/.]+)/menu-items', views.MenuItemViewSet, basename='menu-item')
router.register(r'kitchens/(?P<kitchen_pk>[^/.]+)/plans', views.SubscriptionPlanViewSet, basename='subscription-plan')

urlpatterns = [
    # Auth
    path('send-otp/', views.SendOTPView.as_view(), name='send-otp'),
    path('verify-otp/', views.VerifyOTPView.as_view(), name='verify-otp'),
    path('profile-setup/', views.ProfileSetupView.as_view(), name='profile-setup'),
    path('logout/', views.LogoutView.as_view(), name='logout'),
    path('token/refresh/', views.RefreshTokenView.as_view(), name='token-refresh'),

    # Profile
    path('profile/', views.UserProfileView.as_view(), name='user-profile'),
    path('users/by-uid/<str:uid>/', views.UserProfileByUIDView.as_view(), name='user-by-uid'),
    path('fcm-token/', views.UpdateFCMTokenView.as_view(), name='update-fcm-token'),
    path('favorites/toggle/<str:kitchen_id>/', views.ToggleFavoriteView.as_view(), name='toggle-favorite'),

    # Addresses
    path('addresses/', views.AddressListCreateView.as_view(), name='address-list-create'),
    path('addresses/<int:pk>/', views.AddressDetailView.as_view(), name='address-detail'),

    # Kitchen Categories
    path('kitchen-categories/', views.KitchenCategoryListView.as_view(), name='kitchen-categories'),

    # Kitchens
    path('kitchens/', views.KitchenListCreateView.as_view(), name='kitchen-list-create'),
    path('kitchens/<int:pk>/', views.KitchenDetailView.as_view(), name='kitchen-detail'),
    path('kitchens/<int:pk>/status/', views.KitchenStatusUpdateView.as_view(), name='kitchen-status-update'),
    path('kitchens/<int:pk>/toggle-open/', views.KitchenToggleOpenView.as_view(), name='kitchen-toggle-open'),

    # Kitchen sub-resources (non-viewset)
    path('kitchens/<int:kitchen_pk>/daily-menus/', views.DailyMenuListCreateView.as_view(), name='daily-menu-list-create'),
    path('kitchens/<int:kitchen_pk>/daily-menus/<int:pk>/', views.DailyMenuDetailView.as_view(), name='daily-menu-detail'),

    # Kitchen Images
    path('kitchens/<int:kitchen_pk>/images/', views.KitchenImageUploadView.as_view(), name='kitchen-image-upload'),
    path('kitchens/<int:kitchen_pk>/images/delete/', views.KitchenImageDeleteView.as_view(), name='kitchen-image-delete'),
    path('upload/', views.FileUploadView.as_view(), name='file-upload'),

    # Orders
    path('orders/', views.OrderListCreateView.as_view(), name='order-list-create'),
    path('orders/<int:pk>/', views.OrderDetailView.as_view(), name='order-detail'),
    path('orders/<int:pk>/status/', views.OrderStatusUpdateView.as_view(), name='order-status-update'),
    path('orders/place/', views.PlaceOrderView.as_view(), name='place-order'),
    path('orders/place-with-wallet/', views.PlaceOrderWithWalletView.as_view(), name='place-order-wallet'),
    path('orders/payment-success/', views.PaymentSuccessView.as_view(), name='payment-success'),
    path('orders/skip-meal/', views.SkipMealView.as_view(), name='skip-meal'),
    path('orders/cancel-subscription/', views.CancelSubscriptionView.as_view(), name='cancel-subscription'),

    # Delivery Logs
    path('orders/<int:order_id>/delivery-logs/', views.DeliveryLogListView.as_view(), name='delivery-log-list'),
    path('delivery-logs/', views.CreateDeliveryLogView.as_view(), name='create-delivery-log'),
    path('delivery-logs/feedback/', views.SubmitDailyFeedbackView.as_view(), name='submit-feedback'),

    # Delivery Partner
    path('delivery/available/', views.AvailableDeliveriesView.as_view(), name='available-deliveries'),
    path('delivery/<int:pk>/accept/', views.AcceptDeliveryView.as_view(), name='accept-delivery'),
    path('delivery/my-deliveries/', views.MyDeliveriesView.as_view(), name='my-deliveries'),
    path('delivery/history/', views.MyDeliveryHistoryView.as_view(), name='delivery-history'),
    path('delivery/<int:pk>/status/', views.UpdateDeliveryStatusView.as_view(), name='update-delivery-status'),
    path('delivery/<int:pk>/verify-otp/', views.VerifyDeliveryOTPView.as_view(), name='verify-delivery-otp'),
    path('orders/<int:pk>/generate-delivery-otp/', views.GenerateDeliveryOTPView.as_view(), name='generate-delivery-otp'),
    path('delivery/earnings/', views.DeliveryEarningsView.as_view(), name='delivery-earnings'),
    path('delivery/availability/', views.DeliveryAvailabilityView.as_view(), name='delivery-availability'),

    # Wallet
    path('wallet/', views.WalletView.as_view(), name='wallet'),

    # Reviews
    path('kitchens/<int:kitchen_pk>/reviews/', views.KitchenReviewListView.as_view(), name='kitchen-reviews'),
    path('reviews/', views.CreateReviewView.as_view(), name='create-review'),

    # Coupons
    path('coupons/validate/', views.CouponValidateView.as_view(), name='coupon-validate'),
    path('coupons/', views.CouponListCreateView.as_view(), name='coupon-list-create'),
    path('coupons/<int:pk>/', views.CouponDetailView.as_view(), name='coupon-detail'),

    # Notifications
    path('notifications/', views.NotificationListView.as_view(), name='notification-list'),
    path('notifications/<int:pk>/read/', views.MarkNotificationReadView.as_view(), name='mark-notification-read'),
    path('notifications/read-all/', views.MarkAllNotificationsReadView.as_view(), name='mark-all-read'),
    path('notifications/unread-count/', views.UnreadNotificationCountView.as_view(), name='unread-count'),

    # Support Tickets
    path('support-tickets/', views.SupportTicketListCreateView.as_view(), name='support-ticket-list-create'),
    path('support-tickets/<int:pk>/', views.SupportTicketDetailView.as_view(), name='support-ticket-detail'),

    # Chat
    path('chat/messages/', views.ChatMessageListView.as_view(), name='chat-messages'),
    path('chat/send/', views.SendChatMessageView.as_view(), name='chat-send'),
    path('chat/mark-read/', views.MarkChatReadView.as_view(), name='chat-mark-read'),
    path('chat/contacts/', views.ChatContactsView.as_view(), name='chat-contacts'),

    # Banners
    path('banners/', views.BannerListCreateView.as_view(), name='banner-list-create'),
    path('banners/<int:pk>/', views.BannerDetailView.as_view(), name='banner-detail'),

    # Admin
    path('admin/dashboard/', views.AdminDashboardView.as_view(), name='admin-dashboard'),
    path('admin/users/', views.AdminUserListView.as_view(), name='admin-user-list'),
    path('admin/users/<str:uid>/', views.AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('admin/kitchens/', views.AdminKitchenListView.as_view(), name='admin-kitchen-list'),
    path('admin/orders/', views.AdminOrderListView.as_view(), name='admin-order-list'),
    path('admin/payouts/', views.AdminPayoutListView.as_view(), name='admin-payout-list'),
    path('admin/payouts/<int:pk>/status/', views.AdminPayoutUpdateView.as_view(), name='admin-payout-update'),
    path('admin/settings/', views.AdminSettingListView.as_view(), name='admin-setting-list'),
    path('admin/settings/<int:pk>/', views.AdminSettingDetailView.as_view(), name='admin-setting-detail'),

    # Chef Payouts
    path('payouts/', views.ChefPayoutListCreateView.as_view(), name='chef-payout-list-create'),

    # Delivery Documents
    path('delivery/documents/', views.DeliveryDocumentListView.as_view(), name='delivery-document-list'),
    path('delivery/documents/upload/', views.DeliveryDocumentUploadView.as_view(), name='delivery-document-upload'),
    path('delivery/documents/<int:pk>/', views.DeliveryDocumentDetailView.as_view(), name='delivery-document-detail'),
    path('delivery/documents/<int:pk>/delete/', views.DeliveryDocumentDeleteView.as_view(), name='delivery-document-delete'),
    path('admin/delivery-partners/', views.AdminDeliveryPartnersView.as_view(), name='admin-delivery-partners'),
    path('admin/delivery-documents/', views.AdminDeliveryDocumentListView.as_view(), name='admin-delivery-documents'),
    path('admin/delivery-documents/<int:pk>/status/', views.AdminDeliveryDocumentUpdateView.as_view(), name='admin-delivery-document-status'),

    # Debug (temporary)
    path('_debug/test-email/', views.DebugTestEmailView.as_view(), name='debug-test-email'),

    # Map
    path('map/route/', views.MapRouteView.as_view(), name='map-route'),

    # Include router URLs
    path('', include(router.urls)),
]
