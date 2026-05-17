import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons, Material, MaterialPageRoute;
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
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xFF1A1A1A),
        activeColor: const Color(0xFFE67E22),
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bus),
            label: 'ROUTES',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'PROFILE',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (context) => MyRoutesScreen(focusRouteId: widget.focusRouteId),
            );
          case 1:
            return CupertinoTabView(
              builder: (context) => const ProfileScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (context) => MyRoutesScreen(focusRouteId: widget.focusRouteId),
            );
        }
      },
    );
  }
}
