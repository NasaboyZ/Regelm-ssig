import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zyklustag 24', style: AppTypography.title),
                  const SizedBox(height: 8),
                  Text('Nächste Periode · Vorschau', style: AppTypography.body),
                  const SizedBox(height: 4),
                  Text(
                    '12.–15. September',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          if (index == _selectedIndex) return;
          if (!mounted) return;
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
