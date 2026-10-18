import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/role_config.dart';
import '../sdui/default_config.dart';
import '../sdui/sdui_provider.dart';
import '../sdui/sdui_types.dart';

/// Editable strings for the login screen.
///
/// Deliberately NOT the auth flow. OTP sending, verification and session
/// creation stay in `login_screen.dart` as native Dart — a server-pushed
/// layout must never be able to intercept or reorder credential handling.
///
/// The heading pair comes from the `login` SDUI spec: the first two `text`
/// nodes of the root. Anything missing falls back to the native strings.
class LoginCopy {
  const LoginCopy({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  static const LoginCopy empty = LoginCopy();

  /// Reads the published `login` spec. Never throws.
  static LoginCopy resolve(BuildContext context) {
    try {
      final sdui = context.read<SduiProvider>();
      final spec = sdui.specFor(SduiKeys.login);
      String? title;
      String? subtitle;

      for (final node in spec.root.children) {
        if (node.type != SduiNodeType.text) continue;
        if (node.style == 'h1' || node.style == 'h2') {
          // The first heading wins. Do not let a later h2 overwrite it, which
          // would make the visible title depend on list ordering.
          title ??= node.text.trim().isEmpty ? null : node.text;
        } else if (subtitle == null && node.text.trim().isNotEmpty) {
          subtitle = node.text;
        }
        if (title != null && subtitle != null) break;
      }

      // A dedicated-role build's title comes from RoleConfig ("Welcome to
      // MEALIN RESTO") and should not be overwritten by customer copy.
      if (RoleConfig.isDedicated) return LoginCopy(subtitle: subtitle);

      return LoginCopy(title: title, subtitle: subtitle);
    } catch (_) {
      return LoginCopy.empty;
    }
  }
}