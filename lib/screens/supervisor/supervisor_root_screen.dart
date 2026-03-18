import 'package:flutter/material.dart';
import 'package:aquasense/screens/profile/profile_screen.dart';
import 'package:aquasense/screens/supervisor/supervisor_dashboard_home.dart';
// *** NEW IMPORT ***
import 'package:aquasense/screens/supervisor/billing/billing_dashboard_screen.dart';

class SupervisorRootScreen extends StatefulWidget {
  const SupervisorRootScreen({super.key});

  @override
  State<SupervisorRootScreen> createState() => _SupervisorRootScreenState();
}

class _SupervisorRootScreenState extends State<SupervisorRootScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const SupervisorDashboardHome(), // The main dashboard content
    const BillingDashboardScreen(), // *** NEW: Generate Bill as a primary tab ***
    const ProfileScreen(),          // Re-use the existing profile screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          // *** NEW: Generate Bill Tab ***
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined), // Nice icon for billing
            activeIcon: Icon(Icons.receipt_long),
            label: 'Generate Bill',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF152D4E),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
      ),
    );
  }
}