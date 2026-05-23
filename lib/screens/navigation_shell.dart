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
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: [
                MyRoutesScreen(focusRouteId: widget.focusRouteId),
                const ProfileScreen(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF333333), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, CupertinoIcons.bus, 'ROUTES'),
              _buildNavItem(1, CupertinoIcons.person, 'PROFILE'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE67E22).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: isSelected ? 1.2 : 1.0,
              curve: Curves.elasticOut,
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFFE67E22) : CupertinoColors.systemGrey,
                size: 26,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              color: isSelected ? const Color(0xFFE67E22) : CupertinoColors.systemGrey,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
