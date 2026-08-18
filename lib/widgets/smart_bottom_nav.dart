import 'package:flutter/material.dart';

class SmartBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SmartBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,

      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: "Home",
        ),

        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner),
          label: "Scan",
        ),

        NavigationDestination(
          icon: Icon(Icons.card_giftcard_outlined),
          selectedIcon: Icon(Icons.card_giftcard),
          label: "Rewards",
        ),

        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: "History",
        ),

        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
    );
  }
}