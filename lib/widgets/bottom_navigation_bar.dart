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
  Widget build(BuildContext context) {
    final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.3;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 66 + labelHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                top: 15,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.navigationBarBackground.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(48),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                top: 0,
                left: constraints.maxWidth / 3 * (selectedIndex + 0.5) - 28,
                child: IgnorePointer(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.fontColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundColor,
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _item(context, 0, 'Home', Icons.home_outlined),
                  _item(
                    context,
                    1,
                    'Zyklusverlauf',
                    Icons.calendar_month_outlined,
                  ),
                  _item(context, 2, 'Einstellungen', Icons.tune),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, String label, IconData icon) {
    final selected = selectedIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: Material(
            color: const Color.fromARGB(0, 0, 0, 0),
            child: InkWell(
              onTap: () => onItemSelected(index),
              borderRadius: BorderRadius.circular(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 62,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeInOutCubic,
                      padding: EdgeInsets.only(
                        top: selected ? 0 : 20,
                        bottom: selected ? 6 : 0,
                      ),
                      child: Center(
                        child: TweenAnimationBuilder<Color?>(
                          duration: const Duration(milliseconds: 180),
                          tween: ColorTween(
                            end: selected
                                ? AppColors.backgroundColor
                                : AppColors.fontColor,
                          ),
                          builder: (context, color, _) =>
                              Icon(icon, color: color, size: 26),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.fontColor,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
