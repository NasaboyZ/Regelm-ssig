import 'package:flutter/material.dart';

import '../widgets/bottom_navigation_bar.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Main View')),
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
