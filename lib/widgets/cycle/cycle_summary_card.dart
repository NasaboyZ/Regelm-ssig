import 'package:flutter/material.dart';
import '../../models/cycle_summary.dart';
import '../app_card.dart';
import 'cycle_timeline.dart';
import 'cycle_calendar.dart';

String cycleDateLabel(DateTime date) =>
    '${date.day}. ${monthNames[date.month - 1]} ${date.year}';

class CycleSummaryCard extends StatelessWidget {
  const CycleSummaryCard({
    super.key,
    required this.cycle,
    this.onDetails,
    this.showCalculationDetails = false,
  });
  final CycleSummary cycle;
  final VoidCallback? onDetails;
  final bool showCalculationDetails;
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
            if (onDetails != null)
              TextButton(onPressed: onDetails, child: const Text('Details ›')),
          ],
        ),
        Text(
          cycle.currentStart == null
              ? 'Periodenbeginn noch nicht erfasst'
              : 'Begonnen am ${cycleDateLabel(cycle.currentStart!)}',
        ),
        if (cycle.currentCycleDay != null)
          Text('Zyklustag ${cycle.currentCycleDay}'),
        if (cycle.currentStart != null) CycleTimeline(summary: cycle),
        const Divider(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final cycleAverage = _AverageMetric(
              label: 'Zyklus',
              average: cycle.averageCycleLength,
              basis:
                  'Aus ${cycle.eligibleCycleCount} ${cycle.eligibleCycleCount == 1 ? 'Zyklus' : 'Zyklen'}',
            );
            final periodAverage = _AverageMetric(
              label: 'Periode',
              average: cycle.averagePeriodLength,
              basis:
                  'Aus ${cycle.completedPeriodCount} ${cycle.completedPeriodCount == 1 ? 'Periode' : 'Perioden'}',
            );
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cycleAverage,
                  const SizedBox(height: 12),
                  periodAverage,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cycleAverage),
                const SizedBox(height: 28, child: VerticalDivider(width: 20)),
                Expanded(child: periodAverage),
              ],
            );
          },
        ),
        if (showCalculationDetails) ...[
          const SizedBox(height: 12),
          Text('${cycle.eligibleCycleCount} geeignete abgeschlossene Zyklen'),
          if (cycle.predictionStatus == PredictionStatus.general)
            Text(
              '${cycle.eligibleCycleCount} von 3 Zyklen für eine persönliche Schätzung vorhanden.',
            ),
          if (cycle.estimatedCycleLength != null)
            Text(
              cycle.predictionStatus == PredictionStatus.general
                  ? 'Allgemeiner Richtwert: 28 Tage'
                  : 'Geschätzte Zykluslänge (Median): ${cycle.estimatedCycleLength} Tage',
            ),
          if (cycle.historicalRangeStart != null) ...[
            const SizedBox(height: 8),
            Text(
              'Nach deinen bisherigen Zykluslängen: ${cycleDateLabel(cycle.historicalRangeStart!)} bis ${cycleDateLabel(cycle.historicalRangeEnd!)}',
            ),
            const Text(
              'Dieser Vergleich zeigt bisherige Schwankungen, kein statistisch abgesichertes Vorhersageintervall.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ],
    ),
  );
}

class _AverageMetric extends StatelessWidget {
  const _AverageMetric({
    required this.label,
    required this.average,
    required this.basis,
  });
  final String label;
  final double? average;
  final String basis;

  @override
  Widget build(BuildContext context) {
    final days = average?.round();
    return Column(
      children: [
        Text(
          days == null
              ? 'Ø $label –'
              : 'Ø $label ≈ $days ${days == 1 ? 'Tag' : 'Tage'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          days == null ? 'Noch keine vollständigen Daten' : basis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
