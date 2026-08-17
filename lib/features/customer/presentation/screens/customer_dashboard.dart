import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../chat/presentation/screens/inbox_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/search_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/profile_tab.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const SearchTab(),
    const OrdersTab(),
    const ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mealin"),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InboxScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), activeIcon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
