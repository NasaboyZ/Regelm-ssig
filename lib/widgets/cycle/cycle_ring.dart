import 'package:flutter/material.dart';
import '../../models/cycle_summary.dart';
import '../../theme/app_colors.dart';

class CycleRing extends StatelessWidget {
  const CycleRing({super.key, required this.summary});
  final CycleSummary summary;
  @override
  Widget build(BuildContext context) {
    final day = summary.currentCycleDay;
    final length = summary.estimatedCycleLength;
    return Semantics(
      label: day == null ? 'Periodenbeginn erfassen' : 'Zyklustag $day',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    value: day == null || length == null
                        ? 0
                        : ((day - 1) / length).clamp(0, 1),
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFFE4E4E9),
                    color: AppColors.burntOrange,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Zyklustag', style: TextStyle(fontSize: 12)),
                  Text(
                    day?.toString() ?? '–',
                    style: const TextStyle(fontSize: 40, height: 1.2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
