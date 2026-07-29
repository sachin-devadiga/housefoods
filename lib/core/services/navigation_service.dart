import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigates to a new route without needing BuildContext
  static Future<dynamic> navigateTo(MaterialPageRoute route) {
    return navigatorKey.currentState!.push(route);
  }

  /// Clears the stack and navigates to a new route
  static Future<dynamic> navigateAndRemoveUntil(MaterialPageRoute route) {
    return navigatorKey.currentState!.pushAndRemoveUntil(route, (route) => false);
  }
}
