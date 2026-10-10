import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/cycle_summary.dart';
import '../../models/calendar_date.dart';
import '../../theme/app_colors.dart';

class CycleTimeline extends StatelessWidget {
  const CycleTimeline({super.key, required this.summary});
  final CycleSummary summary;
  @override
  Widget build(BuildContext context) {
    final start = summary.currentStart;
    if (start == null) return const SizedBox.shrink();
    final day = summary.currentCycleDay!;
    final length = math.max(day, summary.estimatedCycleLength ?? day);
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: length,
        itemBuilder: (context, index) {
          final date = addCalendarDays(start, index);
          final bleeding = summary.periodDays.contains(date);
          final today = index + 1 == day;
          return Semantics(
            label:
                'Zyklustag ${index + 1}${today ? ', Heute' : ''}${bleeding ? ', Blutung erfasst' : ''}',
            child: SizedBox(
              width: 12,
              child: Column(
                children: [
                  SizedBox(
                    height: 14,
                    child: today
                        ? const Icon(Icons.arrow_drop_down, size: 14)
                        : null,
                  ),
                  Container(
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: bleeding
                          ? AppColors.burntOrange
                          : const Color(0xFFE4E4E9),
                      borderRadius: BorderRadius.circular(5),
                      border: today
                          ? Border.all(color: AppColors.fontColor)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
