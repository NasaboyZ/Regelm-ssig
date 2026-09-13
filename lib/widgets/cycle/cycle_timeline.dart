import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CycleTimeline extends StatelessWidget {
  const CycleTimeline({
    super.key,
    required this.day,
    required this.length,
    required this.periodLength,
  });
  final int day;
  final int length;
  final int periodLength;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Zyklustag $day von $length',
    child: SizedBox(
      height: 40,
      child: Row(
        children: List.generate(
          length,
          (index) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: Column(
                children: [
                  SizedBox(
                    height: 16,
                    child: index + 1 == day
                        ? const OverflowBox(
                            maxWidth: 30,
                            child: Text('Heute', style: TextStyle(fontSize: 8)),
                          )
                        : null,
                  ),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: index < periodLength
                          ? AppColors.burntOrange
                          : index + 1 < day
                          ? AppColors.pluto
                          : const Color(0xFFE4E4E9),
                      borderRadius: BorderRadius.circular(6),
                      border: index + 1 == day
                          ? Border.all(color: AppColors.fontColor)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
