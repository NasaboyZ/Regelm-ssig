import 'package:flutter/material.dart';

import '../widgets/bottom_navigation_bar.dart';
import '../theme/app_colors.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Main View', style: AppTypography.body)),
      bottomNavigationBar: AppBottomNavigationBar(
        onSearch: () {
          // Handle search action
        },
        onPost: () {
          // Handle post action
        },
        onNotifications: () {
          // Handle notifications action
        },
      ),
    );
  }
}
