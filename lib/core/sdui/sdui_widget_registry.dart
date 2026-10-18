import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

import 'sdui_log.dart';
import 'sdui_types.dart';

/// Renders an [SduiNode] tree.
///
/// This is the extension point for the whole system: adding a new UI
/// capability means adding one entry to [builders] — no Play Store release, no
/// Dart change anywhere else. That property is the entire reason SDUI exists.
///
/// Every builder MUST obey two rules, enforced by [_guard]:
///   1. Never throw. A malformed spec or an unexpected field must cost one
///      widget, not the screen.
///   2. Never assume optional data is present. Everything from the server is
///      attacker-adjacent: an admin can hand-edit a row at any time.
class SduiRenderContext {
  /// Invoked for `open_url` actions.
  final Future<void> Function(String url)? onOpenUrl;

  /// Invoked for `open_screen` actions. The host decides what a screen id means.
  final void Function(String screenId)? onOpenScreen;

  /// Invoked for `dismiss` actions.
  final void Function(String nodeId)? onDismiss;

  const SduiRenderContext({
    this.onOpenUrl,
    this.onOpenScreen,
    this.onDismiss,
  });

  Future<void> runAction(SduiAction action, {String nodeId = ''}) async {
    switch (action.type) {
      case 'open_url':
        if (action.value.isNotEmpty) {
          if (onOpenUrl != null) {
            await onOpenUrl!(action.value);
          } else {
            await openExternal(action.value);
          }
        }
        break;
      case 'open_screen':
        onOpenScreen?.call(action.value);
        break;
      case 'dismiss':
        onDismiss?.call(nodeId);
        break;
      case 'none':
        break;
      default:
        // An unrecognised action is a no-op, never an exception.
        break;
    }
  }

  static Future<void> openExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // A malformed URL is not worth surfacing — the node still rendered.
    }
  }
}

/// Signature every registry entry takes.
typedef SduiNodeBuilder = Widget Function(BuildContext, SduiNode, SduiRenderContext);

class SduiWidgetRegistry {
  SduiWidgetRegistry._();

  /// type -> builder. Every entry in [SduiNodeType.all] must appear here;
  /// `test/sdui_registry_test.dart` fails if one is missing.
  static final Map<String, SduiNodeBuilder> builders = {
    SduiNodeType.column: _column,
    SduiNodeType.row: _row,
    SduiNodeType.container: _container,
    SduiNodeType.section: _section,
    SduiNodeType.text: _text,
    SduiNodeType.button: _button,
    SduiNodeType.bannerCarousel: _bannerCarousel,
    SduiNodeType.promoBanner: _promoBanner,
    SduiNodeType.kitchenCard: _kitchenCard,
    SduiNodeType.dishRow: _dishRow,
    SduiNodeType.list: _list,
    SduiNodeType.grid: _grid,
    SduiNodeType.divider: _divider,
    SduiNodeType.spacer: _spacer,
  };

  /// Build [node], guaranteeing a widget even for unknown or broken input.
  ///
  /// This is safety guarantee #4: a config the client cannot render degrades to
  /// a visible placeholder rather than an exception.
  static Widget build(
    BuildContext context,
    SduiNode node,
    SduiRenderContext ctx,
  ) {
    final builder = builders[node.type];
    if (builder == null) {
      SduiLog.add(
        SduiLogKind.widgetFallback,
        'no builder for type "${node.type}"',
        key: node.id,
      );
      return SduiPlaceholder(reason: 'unknown widget "${node.type}"');
    }
    return _guard(node, () => builder(context, node, ctx));
  }

  /// Render a whole spec.
  static Widget renderSpec(
    BuildContext context,
    SduiSpec spec, {
    SduiRenderContext? ctx,
  }) {
    return build(context, spec.root, ctx ?? const SduiRenderContext());
  }

  static Widget _guard(SduiNode node, Widget Function() build) {
    try {
      return build();
    } catch (e, st) {
      SduiLog.add(
        SduiLogKind.widgetFallback,
        'builder threw for "${node.type}": $e',
        key: node.id,
      );
      assert(() {
        debugPrint('[SDUI] render error in ${node.type}: $e\n$st');
        return true;
      }());
      return SduiPlaceholder(reason: 'could not render "${node.type}"');
    }
  }
}

/// Visible, non-intrusive placeholder for a node that could not be rendered.
///
/// Deliberately small and muted: it should be obvious in QA screenshots without
/// shouting at a real user, and it must not crash or overflow.
class SduiPlaceholder extends StatelessWidget {
  final String reason;

  const SduiPlaceholder({super.key, this.reason = 'unavailable'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              reason,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Widget _column(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Column(
    crossAxisAlignment: node.crossAxisAlign,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final child in node.children)
        Padding(
          padding: node.gap > 0
              ? EdgeInsets.only(bottom: node.gap)
              : EdgeInsets.zero,
          child: SduiWidgetRegistry.build(context, child, ctx),
        ),
    ],
  );
}

Widget _row(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Row(
    crossAxisAlignment: node.crossAxisAlign,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < node.children.length; i++)
        Padding(
          padding: EdgeInsets.only(right: i == node.children.length - 1 ? 0 : node.gap),
          child: SduiWidgetRegistry.build(context, node.children[i], ctx),
        ),
    ],
  );
}

Widget _container(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  Widget child;
  if (node.children.isEmpty) {
    // Valid: a childless container is a tap-target (nav item, card shell).
    child = const SizedBox.shrink();
  } else {
    child = Padding(
      padding: node.padding.toEdgeInsets(),
      child: _column(context, node, ctx),
    );
  }

  final decorated = node.backgroundColor != null || node.borderRadius > 0
      ? Container(
          padding: node.children.isEmpty ? node.padding.toEdgeInsets() : null,
          decoration: BoxDecoration(
            color: _parseColor(node.backgroundColor),
            borderRadius: BorderRadius.circular(node.borderRadius),
          ),
          child: child,
        )
      : child;

  if (node.onTap.isTappable) {
    return GestureDetector(
      onTap: () => ctx.runAction(node.onTap, nodeId: node.id ?? ''),
      behavior: HitTestBehavior.opaque,
      child: decorated,
    );
  }
  return decorated;
}

/// Centred icon glyph used by `promo_banner` and `dish_row` tiles.
Widget _iconGlyph(String? name, double size, Color color) {
  final icon = SduiIcons.resolve(name);
  if (icon == null) return const SizedBox.shrink();
  return Icon(icon, size: size, color: color);
}

Widget _section(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Padding(
    padding: node.padding.toEdgeInsets(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (node.title != null && node.title!.isNotEmpty) ...[
          Text(
            node.title!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (node.subtitle != null && node.subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                node.subtitle!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
        for (final child in node.children)
          Padding(
            padding: EdgeInsets.only(bottom: node.gap),
            child: SduiWidgetRegistry.build(context, child, ctx),
          ),
      ],
    ),
  );
}

Widget _text(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  final style = switch (node.style) {
    'h1' => const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
    'h2' => const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.25),
    'h3' => const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
    'caption' => const TextStyle(fontSize: 12, height: 1.35),
    _ => const TextStyle(fontSize: 15, height: 1.45),
  };
  final resolved = node.color == null
      ? style
      : style.copyWith(color: _parseColor(node.color));

  final icon = SduiIcons.resolve(node.icon);
  return Padding(
    padding: node.padding.toEdgeInsets(),
    child: icon == null
        ? Text(
            node.text,
            style: resolved,
            textAlign: node.align,
            maxLines: node.maxLines > 0 ? node.maxLines : null,
            overflow: node.maxLines > 0 ? TextOverflow.ellipsis : null,
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(
                  icon,
                  size: node.style == 'h1'
                      ? 28
                      : node.style == 'h2'
                          ? 22
                          : 18,
                  color: _parseColor(node.color) ?? AppTheme.primaryColor,
                ),
              ),
              Expanded(
                child: Text(
                  node.text,
                  style: resolved,
                  textAlign: node.align,
                  maxLines: node.maxLines > 0 ? node.maxLines : null,
                  overflow: node.maxLines > 0 ? TextOverflow.ellipsis : null,
                ),
              ),
            ],
          ),
  );
}

Widget _button(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  final (bg, fg) = switch (node.variant) {
    'secondary' => (AppTheme.primaryColor.withValues(alpha: 0.12), AppTheme.primaryColor),
    'ghost' => (Colors.transparent, AppTheme.primaryColor),
    'danger' => (Colors.red.shade600, Colors.white),
    _ => (AppTheme.primaryColor, Colors.white),
  };

  return Padding(
    padding: node.padding.toEdgeInsets(),
    child: SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: node.enabled
            ? () => ctx.runAction(node.action, nodeId: node.id ?? '')
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: node.variant == 'ghost' ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          node.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

Widget _bannerCarousel(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  if (node.banners.isEmpty) {
    return const SizedBox.shrink();
  }
  return SizedBox(
    height: node.height > 0 ? node.height : 160,
    child: PageView.builder(
      itemCount: node.banners.length,
      itemBuilder: (context, index) => _bannerTile(context, node.banners[index], ctx),
    ),
  );
}

Widget _bannerTile(BuildContext context, SduiBanner banner, SduiRenderContext ctx) {
  final image = banner.imageUrl;
  return GestureDetector(
    onTap: () => ctx.runAction(banner.action, nodeId: banner.id),
    child: Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        image: (image != null && image.isNotEmpty)
            ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            banner.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (banner.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              banner.subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _promoBanner(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return GestureDetector(
    onTap: node.action.isTappable
        ? () => ctx.runAction(node.action, nodeId: node.id ?? '')
        : null,
    child: Container(
      margin: node.padding.toEdgeInsets(),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _parseColor(node.backgroundColor) ??
            AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        image: (node.imageUrl != null && node.imageUrl!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(node.imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node.icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _iconGlyph(node.icon, 28, AppTheme.primaryColor),
            ),
          if (node.title != null)
            Text(node.title!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (node.subtitle != null && node.subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(node.subtitle!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ),
        ],
      ),
    ),
  );
}

Widget _kitchenCard(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Container(
    margin: node.padding.toEdgeInsets(),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _thumb(node.imageUrl, 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.name ?? 'Kitchen',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (node.showRating)
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text('New',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _dishRow(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Opacity(
    opacity: node.available ? 1.0 : 0.5,
    child: Container(
      margin: node.padding.toEdgeInsets(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _thumb(node.imageUrl, 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.name ?? 'Dish',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (node.description != null && node.description!.isNotEmpty)
                  Text(
                    node.description!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (node.price != null)
            Text(
              node.price!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    ),
  );
}

Widget _list(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final child in node.children)
        Padding(
          padding: EdgeInsets.only(bottom: node.gap),
          child: SduiWidgetRegistry.build(context, child, ctx),
        ),
    ],
  );
}

Widget _grid(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  final columns = node.columns < 1 ? 1 : node.columns;
  return GridView.count(
    crossAxisCount: columns,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: node.gap,
    crossAxisSpacing: node.gap,
    childAspectRatio: 1.4,
    children: [
      for (final child in node.children)
        SduiWidgetRegistry.build(context, child, ctx),
    ],
  );
}

Widget _divider(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return Padding(
    padding: node.padding.toEdgeInsets(),
    child: Divider(
      height: node.height > 0 ? node.height : 1,
      thickness: 1,
      color: _parseColor(node.color) ?? Colors.grey.shade300,
    ),
  );
}

Widget _spacer(BuildContext context, SduiNode node, SduiRenderContext ctx) {
  return SizedBox(height: node.height > 0 ? node.height : 8);
}

Widget _thumb(String? url, double size) {
  if (url != null && url.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A dead image URL must not produce an exception mid-tree.
        errorBuilder: (context, error, stack) => _thumbFallback(size),
      ),
    );
  }
  return _thumbFallback(size);
}

Widget _thumbFallback(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, size: size * 0.4, color: Colors.grey.shade500),
    );

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) return null;
  // Accept '#RRGGBB' and the common CSS names; anything else is ignored
  // rather than throwing on Color(int.parse).
  if (value.startsWith('#')) {
    final hex = value.replaceFirst('#', '');
    final expanded = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
  switch (value.toLowerCase()) {
    case 'red':
      return Colors.red;
    case 'green':
      return Colors.green;
    case 'blue':
      return Colors.blue;
    case 'orange':
      return Colors.orange;
    case 'black':
      return Colors.black;
    case 'white':
      return Colors.white;
    default:
      return null;
  }
}