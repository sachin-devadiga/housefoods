class AppConstants {
  static const String appName = 'Mealin';

  // API Configuration
  // Override with: --dart-define=API_BASE_URL=http://YOUR_IP:8000
  // Otherwise the app auto-tries localhost, emulator host (10.0.2.2),
  // and your machine's LAN IP so it works on any device without rebuilds.
  static List<String> apiBaseUrlCandidates = _resolveApiBaseUrlCandidates();

  static String apiBaseUrl = apiBaseUrlCandidates.first;

  static List<String> _resolveApiBaseUrlCandidates() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return [fromEnv];

    return ['https://housefoods.onrender.com'];
  }

  // Auth Endpoints
  static const String sendOtpEndpoint = '/api/auth/send-otp/';
  static const String verifyOtpEndpoint = '/api/auth/verify-otp/';
  static const String profileSetupEndpoint = '/api/auth/profile-setup/';
  static const String logoutEndpoint = '/api/auth/logout/';
  static const String tokenRefreshEndpoint = '/api/auth/token/refresh/';
  static const String profileEndpoint = '/api/auth/profile/';
  static const String userByUidEndpoint = '/api/auth/users/by-uid';
  static const String updateFcmTokenEndpoint = '/api/auth/fcm-token/';
  static const String toggleFavoriteEndpoint = '/api/auth/favorites/toggle';

  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String mealImagesPath = 'meal_images';
  static const String kitchenImagesPath = 'kitchen_images';

  // Address Endpoints
  static const String addressesEndpoint = '/api/auth/addresses/';

  // Kitchen Endpoints
  static const String kitchenCategoriesEndpoint = '/api/auth/kitchen-categories/';
  static const String kitchensEndpoint = '/api/auth/kitchens/';
  static const String kitchenStatusEndpoint = '/api/auth/kitchens';
  static const String kitchenToggleOpenEndpoint = '/api/auth/kitchens';
  static const String kitchenDailyMenusEndpoint = '/api/auth/kitchens';
  static const String kitchenImagesEndpoint = '/api/auth/kitchens';
  static const String kitchenReviewsEndpoint = '/api/auth/kitchens';

  // Menu & Plan Endpoints
  static const String menuCategoriesEndpoint = '/api/auth/kitchens';
  static const String menuItemsEndpoint = '/api/auth/kitchens';
  static const String plansEndpoint = '/api/auth/kitchens';

  // Order Endpoints
  static const String ordersEndpoint = '/api/auth/orders/';
  static const String placeOrderEndpoint = '/api/auth/orders/place/';
  static const String placeOrderWithWalletEndpoint = '/api/auth/orders/place-with-wallet/';
  static const String paymentSuccessEndpoint = '/api/auth/orders/payment-success/';
  static const String skipMealEndpoint = '/api/auth/orders/skip-meal/';
  static const String cancelSubscriptionEndpoint = '/api/auth/orders/cancel-subscription/';
  static const String orderStatusEndpoint = '/api/auth/orders';
  static const String deliveryLogsEndpoint = '/api/auth/orders';
  static const String createDeliveryLogEndpoint = '/api/auth/delivery-logs/';
  static const String submitFeedbackEndpoint = '/api/auth/delivery-logs/feedback/';

  // Delivery Partner Endpoints
  static const String availableDeliveriesEndpoint = '/api/auth/delivery/available/';
  static const String acceptDeliveryEndpoint = '/api/auth/delivery';
  static const String myDeliveriesEndpoint = '/api/auth/delivery/my-deliveries/';
  static const String deliveryHistoryEndpoint = '/api/auth/delivery/history/';
  static const String updateDeliveryStatusEndpoint = '/api/auth/delivery';
  static const String verifyDeliveryOtpEndpoint = '/api/auth/delivery';
  static const String generateDeliveryOtpEndpoint = '/api/auth/orders';
  static const String deliveryEarningsEndpoint = '/api/auth/delivery/earnings/';
  static const String deliveryAvailabilityEndpoint = '/api/auth/delivery/availability/';

  // Wallet
  static const String walletEndpoint = '/api/auth/wallet/';
  static const String referralsEndpoint = '/api/auth/referrals/apply/';

  // Reviews
  static const String reviewsEndpoint = '/api/auth/reviews/';

  // Coupons
  static const String couponValidateEndpoint = '/api/auth/coupons/validate/';
  static const String couponsEndpoint = '/api/auth/coupons/';

  // Notifications
  static const String notificationsEndpoint = '/api/auth/notifications/';
  static const String markNotificationReadEndpoint = '/api/auth/notifications';
  static const String markAllNotificationsReadEndpoint = '/api/auth/notifications/read-all/';
  static const String unreadCountEndpoint = '/api/auth/notifications/unread-count/';

  // Support Tickets
  static const String supportTicketsEndpoint = '/api/auth/support-tickets/';

  // Chat
  static const String chatMessagesEndpoint = '/api/auth/chat/messages/';
  static const String chatSendEndpoint = '/api/auth/chat/send/';
  static const String chatMarkReadEndpoint = '/api/auth/chat/mark-read/';
  static const String chatContactsEndpoint = '/api/auth/chat/contacts/';

  // Banners
  static const String bannersEndpoint = '/api/auth/banners/';

  // Admin
  static const String adminDashboardEndpoint = '/api/auth/admin/dashboard/';
  static const String adminUsersEndpoint = '/api/auth/admin/users/';
  static const String adminKitchensEndpoint = '/api/auth/admin/kitchens/';
  static const String adminOrdersEndpoint = '/api/auth/admin/orders/';
  static const String adminPayoutsEndpoint = '/api/auth/admin/payouts/';
  static const String adminSettingsEndpoint = '/api/auth/admin/settings/';
  static const String adminDeliveryPartnersEndpoint = '/api/auth/admin/delivery-partners/';
  static const String adminDeliveryDocumentsEndpoint = '/api/auth/admin/delivery-documents/';

  // Map
  static const String mapRouteEndpoint = '/api/auth/map/route/';

  // Rider Location Tracking
  static const String riderLocationUpdateEndpoint = '/api/auth/delivery/location/';
  static String riderLocationEndpoint(dynamic orderId) => '/api/auth/orders/$orderId/rider-location/';

  // Delivery Documents
  static const String deliveryDocumentsEndpoint = '/api/auth/delivery/documents/';
  static const String deliveryDocumentUploadEndpoint = '/api/auth/delivery/documents/upload/';
  static const String deliveryDocumentDetailEndpoint = '/api/auth/delivery/documents';
  static const String deliveryDocumentDeleteEndpoint = '/api/auth/delivery/documents';

  // Cart
  static const String cartEndpoint = '/api/auth/cart/';
  static const String cartItemsEndpoint = '/api/auth/cart/items/';
  static const String cartClearEndpoint = '/api/auth/cart/clear/';

  // Razorpay
  // Override with: --dart-define=RAZORPAY_KEY=rzp_live_xxxx
  static const String razorpayKey = String.fromEnvironment('RAZORPAY_KEY', defaultValue: 'rzp_test_YOUR_KEY_HERE');

  // Gemini AI
  // Override with: --dart-define=GEMINI_API_KEY=your_key_here
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // Upload
  static const String uploadEndpoint = '/api/auth/upload/';

  // Chef Payouts
  static const String payoutsEndpoint = '/api/auth/payouts/';

  // App Version
  static const String appVersionEndpoint = '/api/auth/app-version/';

  // Delivery Partner Payouts
  static const String deliveryPayoutsEndpoint = '/api/auth/delivery/payouts/';

  // Shared Preferences Keys
  static const String isFirstRun = 'is_first_run';
  static const String userRole = 'user_role';
  static const String sessionEmail = 'session_email';
  static const String sessionUid = 'session_uid';
}
