import 'package:flutter/material.dart';
import '../theme/design_system.dart';
import 'create_route_screen.dart';
import 'my_routes_screen.dart';
import 'profile_screen.dart';

class NavigationShell extends StatefulWidget {
  final String? focusRouteId;
  const NavigationShell({super.key, this.focusRouteId});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0; // Routes is now the only main tab after removing Dashboard

  List<Widget> get _pages => [
    MyRoutesScreen(focusRouteId: widget.focusRouteId),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF333333), width: 2)),
          ),
          child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1E1E1E),
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: [
            _buildNavItem(Icons.local_shipping, 'Routes', 0),
            _buildNavItem(Icons.person, 'Profile', 1),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRouteScreen()),
                );
              },
              backgroundColor: AppDesignSystem.primary,
              child: const Icon(Icons.add, color: AppDesignSystem.onPrimary),
            )
          : null,
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        width: double.infinity,
        height: 72, // Match parent height
        color: isSelected ? AppDesignSystem.primary : Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.grey[400]),
            Text(label.toUpperCase(), style: TextStyle(
              color: isSelected ? Colors.black : Colors.grey[400],
              fontWeight: FontWeight.w900,
              fontSize: 12,
            )),
          ],
        ),
      ),
      label: '', // Label is handled inside the icon container for full-width background effect
    );
  }
}
