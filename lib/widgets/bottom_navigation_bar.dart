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

  static const _labels = ['Search', 'Post', 'Notifs'];
  static const _icons = [Icons.search, Icons.add, Icons.notifications_none];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _labels.length;
              return Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.navigationBarBackground,
                      borderRadius: BorderRadius.circular(40),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          for (var index = 0; index < _labels.length; index++)
                            Expanded(
                              child: _NavigationItem(
                                icon: _icons[index],
                                label: _labels[index],
                                selected: selectedIndex == index,
                                onTap: () => onItemSelected(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Centre the circle over the selected third of the bar.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    top: 0,
                    left: itemWidth * (selectedIndex + 0.5) - 28,
                    width: 56,
                    height: 56,
                    // The corresponding navigation item provides semantics.
                    child: ExcludeSemantics(
                      child: Material(
                        key: const ValueKey('navigation-selection'),
                        color: AppColors.fontColor,
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: AppColors.backgroundColor,
                            width: 4,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          onPressed: () => onItemSelected(selectedIndex),
                          tooltip: _labels[selectedIndex],
                          icon: Icon(_icons[selectedIndex]),
                          iconSize: 32,
                          color: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.onTap,
    required this.icon,
    required this.selected,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: selected
                    ? null
                    : Icon(icon, size: 25, color: AppColors.fontColor),
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTypography.nav),
            ],
          ),
        ),
      ),
    );
  }
}
