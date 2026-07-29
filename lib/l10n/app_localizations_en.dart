// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'HouseFoods';

  @override
  String get welcomeTitle => 'Welcome to HouseFoods';

  @override
  String get loginPrompt => 'Enter your phone number to continue';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get home => 'Home';

  @override
  String get search => 'Search';

  @override
  String get orders => 'Orders';

  @override
  String get profile => 'Profile';

  @override
  String get trackMeal => 'Track Today\'s Meal';

  @override
  String get renewNow => 'Renew Now';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';
}
