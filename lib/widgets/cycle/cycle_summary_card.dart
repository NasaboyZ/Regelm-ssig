import 'package:flutter/material.dart';
import '../../models/cycle_data.dart';
import '../../theme/app_colors.dart';
import '../app_card.dart';
import 'cycle_timeline.dart';
import 'cycle_calendar.dart';

class CycleSummaryCard extends StatelessWidget {
  const CycleSummaryCard({
    super.key,
    required this.cycle,
    required this.onDetails,
  });
  final CycleData cycle;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Aktueller Zyklus',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            TextButton(onPressed: onDetails, child: const Text('Details ›')),
          ],
        ),
        Text(
          'Begonnen am ${cycle.start.day}. ${monthNames[cycle.start.month - 1]}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          'Zyklustag ${cycle.day} von durchschnittlich ${cycle.length} Tagen',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        CycleTimeline(
          day: cycle.day,
          length: cycle.length,
          periodLength: cycle.periodLength,
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              'Ø Zyklus ${cycle.length} Tage',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12, child: VerticalDivider()),
            Text(
              'Ø Periode ${cycle.periodLength} Tage',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}
