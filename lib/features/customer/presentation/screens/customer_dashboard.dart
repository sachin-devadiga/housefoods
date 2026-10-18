import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/sdui/default_config.dart';
import '../../../../core/sdui/sdui_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ai_assistant/presentation/screens/ai_chat_screen.dart';
import '../../../chat/presentation/screens/inbox_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/search_tab.dart';
import 'tabs/subscriptions_tab.dart';

/// One bottom-nav destination.
class CustomerNavItem {
  /// Stable id used by the server config, e.g. `nav_home`.
  final String id;

  /// Screen implementation. Held here rather than in the SDUI spec on purpose:
  /// the server decides *which tabs exist, in what order, and what they are
  /// called*, never which Dart code runs.
  final Widget screen;

  final String label;
  final IconData icon;
  final IconData activeIcon;

  const CustomerNavItem({
    required this.id,
    required this.screen,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// The fixed catalogue of tabs this build can show.
///
/// SDUI can reorder, rename, disable or add deep links for these, but cannot
/// invent a screen. That boundary is deliberate: a server-pushed layout can
/// change what a user sees, never what the app is capable of executing.
const List<CustomerNavItem> kCustomerNavCatalog = [
  CustomerNavItem(
    id: 'nav_home',
    screen: HomeTab(),
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),
  CustomerNavItem(
    id: 'nav_orders',
    screen: OrdersTab(),
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  CustomerNavItem(
    id: 'nav_search',
    screen: SearchTab(),
    label: 'Search',
    icon: Icons.search,
    activeIcon: Icons.search_rounded,
  ),
  CustomerNavItem(
    id: 'nav_subscriptions',
    screen: SubscriptionsTab(),
    label: 'Plans',
    icon: Icons.autorenew_outlined,
    activeIcon: Icons.autorenew,
  ),
  CustomerNavItem(
    id: 'nav_profile',
    screen: ProfileTab(),
    label: 'Profile',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];

/// Customer shell with a server-configurable bottom navigation bar.
///
/// Order, labels and visibility come from the `customer_nav` SDUI spec or the
/// `navigation` block in the bootstrap payload. If neither is present or valid,
/// the native five-tab order is used unchanged — which is the default, so a
/// missing config is indistinguishable from today's app.
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  /// Tab ids in the order currently displayed.
  List<String> _visibleIds() {
    final sdui = context.read<SduiProvider>();

    // Preferred source: the `customer_nav` screen spec, which expresses the
    // order as a list of childless containers with on_tap open_screen values.
    final spec = sdui.specFor(SduiKeys.customerNav);
    final fromSpec = _idsFromSpec(spec);
    if (fromSpec.isNotEmpty) return fromSpec;

    // Secondary source: the bootstrap `navigation` block, which admins may
    // prefer because it needs no spec authoring.
    final nav = sdui.navigation['customer'];
    if (nav is Map && nav['items'] is List) {
      final fromNav = _idsFromNavigation(nav['items'] as List);
      if (fromNav.isNotEmpty) return fromNav;
    }

    return kCustomerNavCatalog.map((e) => e.id).toList();
  }

  List<String> _idsFromSpec(dynamic spec) {
    final ids = <String>[];
    for (final node in spec.root.children) {
      final value = node.onTap.type == 'open_screen' ? node.onTap.value : null;
      if (value == null || value.isEmpty) continue;
      if (!_isKnown(value)) continue;
      if (!ids.contains(value)) ids.add(value);
    }
    return ids;
  }

  List<String> _idsFromNavigation(List items) {
    final enabled = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is Map<String, dynamic> && item['enabled'] != false) {
        enabled.add(item);
      }
    }
    enabled.sort((a, b) {
      final ao = (a['order'] as num?)?.toInt() ?? 0;
      final bo = (b['order'] as num?)?.toInt() ?? 0;
      return ao.compareTo(bo);
    });
    final ids = <String>[];
    for (final item in enabled) {
      final id = item['id'] as String?;
      if (id != null && _isKnown(id) && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  static bool _isKnown(String id) =>
      kCustomerNavCatalog.any((item) => item.id == id);

  CustomerNavItem _byId(String id) =>
      kCustomerNavCatalog.firstWhere((item) => item.id == id);

  @override
  Widget build(BuildContext context) {
    // watch() so a config refresh reorders the bar without a restart.
    context.watch<SduiProvider>();
    final ids = _visibleIds();
    // A config that hides the selected tab must not leave the index dangling.
    final safeIndex = _selectedIndex.clamp(0, ids.length - 1);
    final items = ids.map(_byId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEALIN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: safeIndex,
        children: [for (final item in items) item.screen],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          for (final item in items)
            BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.activeIcon),
              label: item.label,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiChatScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }
}