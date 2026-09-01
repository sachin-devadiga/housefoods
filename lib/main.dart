import 'dart:io' show Platform;
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/language_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/navigation_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/constants/app_constants.dart';
import 'core/error/error_screen.dart';
import 'core/widgets/no_internet_overlay.dart';
import 'features/admin/presentation/providers/admin_provider.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/user_repository_impl.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/chef/presentation/providers/chef_provider.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/presentation/providers/chat_provider.dart';
import 'features/customer/data/repositories/kitchen_repository_impl.dart';
import 'features/map/providers/map_provider.dart';
import 'features/customer/data/repositories/order_repository_impl.dart';
import 'features/customer/data/repositories/review_repository_impl.dart';
import 'features/customer/presentation/providers/kitchen_provider.dart';
import 'features/customer/presentation/providers/order_provider.dart';
import 'features/customer/presentation/providers/review_provider.dart';
import 'features/customer/presentation/providers/favorites_provider.dart';
import 'features/customer/presentation/providers/cart_provider.dart';
import 'features/notifications/data/repositories/notification_repository_impl.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/support/presentation/providers/support_provider.dart';
import 'features/rewards/presentation/providers/reward_provider.dart';
import 'features/delivery_partner/presentation/providers/delivery_partner_provider.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'meal_voice/meal_voice_controller.dart';

void main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Uncaught Async Error: $error");
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isAndroid) {
    debugPrint('[MEALIN] Running on Android device');
    debugPrint('[MEALIN] API URL: ${AppConstants.apiBaseUrl}');
    if (AppConstants.apiBaseUrl.contains('10.0.2.2')) {
      debugPrint('[MEALIN] For physical devices, run: flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000');
      debugPrint('[MEALIN] Or use: adb reverse tcp:8000 tcp:8000  (then localhost works)');
    }
  } else {
    debugPrint('[MEALIN] API URL: ${AppConstants.apiBaseUrl}');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Critical initialization error: $e");
  }

  runApp(const MealinApp());
}

class MealinApp extends StatelessWidget {
  const MealinApp({super.key});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorScreen(errorDetails: details);
    };

    final apiService = ApiService(baseUrl: AppConstants.apiBaseUrl);
    final userRepository = UserRepositoryImpl(apiService: apiService);
    final kitchenRepository = KitchenRepositoryImpl(apiService: apiService);
    final chatRepository = ChatRepositoryImpl(apiService: apiService);
    final notificationRepository = NotificationRepositoryImpl(apiService: apiService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            AuthRepositoryImpl(),
            authService: AuthService(apiService: apiService),
          ),
        ),
        ChangeNotifierProvider(create: (_) => KitchenProvider(kitchenRepository)),
        ChangeNotifierProvider(create: (_) => OrderProvider(OrderRepositoryImpl(apiService: apiService), apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ChefProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => AdminProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ReviewProvider(ReviewRepositoryImpl(apiService: apiService))),
        ChangeNotifierProvider(create: (_) => FavoritesProvider(userRepository)),
        ChangeNotifierProvider(create: (_) => ChatProvider(chatRepository)),
        ChangeNotifierProvider(create: (_) => SupportProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => RewardProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => DeliveryPartnerProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (context) => MapProvider(
          connectivityService: context.read<ConnectivityService>(),
        )),
        ChangeNotifierProvider(create: (_) => NotificationProvider(notificationRepository)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MealVoiceController()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return MaterialApp(
            title: 'Mealin',
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: languageProvider.locale,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
            ],
            builder: (context, child) {
              return NoInternetOverlay(child: child!);
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
