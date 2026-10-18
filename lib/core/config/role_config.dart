import 'package:flutter/material.dart';

enum AppRole { customer, chef, deliveryPartner }

class RoleConfig {
  static const String _envRole = String.fromEnvironment('APP_ROLE', defaultValue: '');

  static AppRole? get role {
    switch (_envRole) {
      case 'customer':
        return AppRole.customer;
      case 'chef':
        return AppRole.chef;
      case 'delivery_partner':
        return AppRole.deliveryPartner;
      default:
        return null;
    }
  }

  static bool get isDedicated => role != null;

  static String get roleName {
    switch (role) {
      case AppRole.customer:
        return 'customer';
      case AppRole.chef:
        return 'chef';
      case AppRole.deliveryPartner:
        return 'delivery_partner';
      case null:
        return '';
    }
  }

  static String get appName {
    switch (role) {
      case AppRole.customer:
        return 'MEALIN';
      case AppRole.chef:
        return 'MEALIN RESTO';
      case AppRole.deliveryPartner:
        return 'MEALIN RIDER';
      case null:
        return 'MEALIN';
    }
  }

  static String get splashSubtitle {
    switch (role) {
      case AppRole.customer:
        return 'Fresh food, delivered fast';
      case AppRole.chef:
        return 'Your kitchen, your rules';
      case AppRole.deliveryPartner:
        return 'Earn on your schedule';
      case null:
        return '';
    }
  }

  /// Brand mark for the splash screen. The resto app ships a green recolour
  /// of the same glyph so a kitchen phone does not look like the customer app.
  static String get logoAsset {
    switch (role) {
      case AppRole.chef:
        return 'assets/logo_green.png';
      case AppRole.customer:
      case AppRole.deliveryPartner:
      case null:
        return 'assets/logo.jpeg';
    }
  }

  /// Brand colour for this role's splash.
  ///
  /// The resto app is green end-to-end (its UI already uses
  /// AppTheme.secondaryColor); this keeps the splash from flashing the
  /// customer app's orange before the first frame.
  static Color get splashColor {
    switch (role) {
      case AppRole.chef:
        return const Color(0xFF43A047); // Green 600
      case AppRole.customer:
      case AppRole.deliveryPartner:
      case null:
        return const Color(0xFFFF5722); // Deep Orange
    }
  }

  static String get loginTitle {
    switch (role) {
      case AppRole.customer:
        return 'Welcome to MEALIN';
      case AppRole.chef:
        return 'Welcome to MEALIN RESTO';
      case AppRole.deliveryPartner:
        return 'Welcome to MEALIN RIDER';
      case null:
        return 'Welcome to MEALIN';
    }
  }
}
