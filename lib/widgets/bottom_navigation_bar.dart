import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 3);
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFEDEBED))),
    ),
    child: BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemSelected,
      backgroundColor: AppColors.backgroundColor,
      elevation: 0,
      selectedItemColor: AppColors.burntOrange,
      unselectedItemColor: AppColors.muted,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Zyklusverlauf',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Einstellungen'),
      ],
    ),
  );
}
