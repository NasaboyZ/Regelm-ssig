import 'package:flutter/material.dart';

import '../widgets/bottom_navigation_bar.dart';
import '../theme/app_colors.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Main View', style: AppTypography.body)),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          if (index == _selectedIndex) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
