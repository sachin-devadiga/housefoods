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
        return 'Mealin';
      case AppRole.chef:
        return 'Mealin Kitchen';
      case AppRole.deliveryPartner:
        return 'Mealin Delivery';
      case null:
        return 'Mealin';
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

  static String get loginTitle {
    switch (role) {
      case AppRole.customer:
        return 'Welcome to Mealin';
      case AppRole.chef:
        return 'Welcome to Mealin Kitchen';
      case AppRole.deliveryPartner:
        return 'Welcome to Mealin Delivery';
      case null:
        return 'Welcome to Mealin';
    }
  }
}
