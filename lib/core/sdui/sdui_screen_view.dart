import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../sdui/sdui_log.dart';
import '../sdui/sdui_provider.dart';
import '../sdui/sdui_types.dart';
import '../sdui/sdui_widget_registry.dart';

/// Renders a server-driven surface, with a native fallback.
///
/// This is the widget that makes converting a screen safe:
///
///   * No spec, or the backend is unreachable -> [fallback] renders. The native
///     implementation stays authoritative until an admin actually publishes
///     something.
///   * Spec present and valid -> rendered through the registry.
///   * Spec present but broken -> [fallback] renders, and the failure is logged
///     so it shows up on the diagnostics screen.
///
/// A spec that expresses no opinion (an empty column, or a zero-height spacer)
/// is treated as absent, so shipping a placeholder default never silently hides
/// a native surface. That is what lets `default_config.dart` exist for every key
/// without every surface being overridden by default.
class SduiScreenView extends StatelessWidget {
  const SduiScreenView({
    super.key,
    required this.specKey,
    required this.fallback,
    this.renderContext,
    this.padding = EdgeInsets.zero,
  });

  /// Key into [SduiProvider.specs], e.g. `SduiKeys.banners`.
  final String specKey;

  /// Native widget used whenever SDUI has nothing usable to show.
  final Widget fallback;

  /// Action wiring. Defaults to handling `open_url` only.
  final SduiRenderContext? renderContext;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final sdui = context.watch<SduiProvider>();
    final spec = sdui.specFor(specKey);

    if (!sdui.isRenderable(specKey)) {
      return fallback;
    }

    try {
      final widget = SduiWidgetRegistry.build(
        context,
        spec.root,
        renderContext ?? const SduiRenderContext(),
      );
      return Padding(padding: padding, child: widget);
    } catch (e) {
      // A throw here would take down the whole tab, so degrade instead.
      SduiLog.add(
        SduiLogKind.widgetFallback,
        'SduiScreenView("$specKey") failed: $e',
        key: specKey,
      );
      return fallback;
    }
  }
}

/// Convenience wrapper for a whole spec body without a fallback.
///
/// Used where the SDUI surface is genuinely new (banners) rather than a
/// replacement for existing native code.
class SduiSpecBody extends StatelessWidget {
  const SduiSpecBody({
    super.key,
    required this.specKey,
    this.renderContext,
  });

  final String specKey;
  final SduiRenderContext? renderContext;

  @override
  Widget build(BuildContext context) {
    final sdui = context.watch<SduiProvider>();
    final spec = sdui.specFor(specKey);
    if (!sdui.isRenderable(specKey)) return const SizedBox.shrink();

    return SduiWidgetRegistry.build(
      context,
      spec.root,
      renderContext ?? const SduiRenderContext(),
    );
  }
}

/// Reports whether a spec expresses an actual opinion.
///
/// A spec whose root is a zero-height spacer, or a layout type with no
/// children, renders nothing. Treating that as "present" would let a default
/// spec blank out a working native surface, so it is treated as absent.
bool specIsRenderable(SduiSpec spec) {
  final root = spec.root;
  if (root.type == SduiNodeType.spacer) return root.height > 0;
  if (SduiNodeType.containers.contains(root.type)) {
    return root.children.isNotEmpty;
  }
  return true;
}