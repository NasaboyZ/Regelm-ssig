import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.onSearch,
    required this.onPost,
    required this.onNotifications,
  });

  final VoidCallback onSearch;
  final VoidCallback onPost;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 88,
          child: Stack(
            children: [
              // Abgerundeter Hintergrund mit den drei Aktionen.
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.NavigationBarBackground,
                  borderRadius: BorderRadius.circular(40),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.search,
                          label: 'Search',
                          onTap: onSearch,
                        ),
                      ),
                      Expanded(
                        child: _NavigationItem(label: 'Post', onTap: onPost),
                      ),
                      Expanded(
                        child: _NavigationItem(
                          icon: Icons.notifications_none,
                          label: 'Notifs',
                          onTap: onNotifications,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Erhöhter Plus-Button in der Mitte.
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Material(
                    color: AppColors.fontColor,
                    shape: const CircleBorder(
                      side: BorderSide(
                        color: AppColors.backgroundColor,
                        width: 4,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      onPressed: onPost,
                      tooltip: 'Beitrag erstellen',
                      icon: const Icon(Icons.add),
                      iconSize: 32,
                      color: AppColors.backgroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: icon == null
                  ? null
                  : Icon(icon, size: 25, color: AppColors.fontColor),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTypography.nav),
          ],
        ),
      ),
    );
  }
}
