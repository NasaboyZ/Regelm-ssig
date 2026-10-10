import '../models/day_entry.dart';
import '../models/period_entry.dart';
import '../models/cycle_summary.dart';

/// A calendar estimate never creates or modifies an observed bleeding entry.
class CycleCalculationService {
  const CycleCalculationService();
  CycleSummary calculate(TrackingSnapshot snapshot, DateTime now) {
    final today = localDay(now);
    final periods =
        snapshot.periods
            .where(
              (p) => p.type == BleedingType.period && !p.start.isAfter(today),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final lengths = <int>[];
    for (var i = 1; i < periods.length; i++) {
      final length = calendarDaysBetween(
        periods[i - 1].start,
        periods[i].start,
      );
      if (length > 0 && !periods[i].gapBefore) lengths.add(length);
    }
    final used =
        lengths.skip(lengths.length > 6 ? lengths.length - 6 : 0).toList()
          ..sort();
    final periodLengths = periods
        .where((p) => p.end != null && !p.end!.isAfter(today))
        .map((p) => calendarDaysBetween(p.start, p.end!) + 1)
        .where((length) => length > 0)
        .toList();
    final start = periods.isEmpty ? null : periods.last.start;
    final status = start == null
        ? PredictionStatus.missingStart
        : snapshot.forecastConsent != ForecastConsent.yes
        ? PredictionStatus.disabled
        : lengths.length < 3
        ? PredictionStatus.general
        : PredictionStatus.personal;
    int? estimate;
    if (status == PredictionStatus.general) estimate = 28;
    if (status == PredictionStatus.personal) {
      final middle = used.length ~/ 2;
      estimate = used.length.isOdd
          ? used[middle]
          : ((used[middle - 1] + used[middle]) / 2).round();
    }
    final personal = status == PredictionStatus.personal;
    final periodDays = <DateTime>{};
    final spottingDays = <DateTime>{};
    for (final p in snapshot.periods) {
      (p.type == BleedingType.period ? periodDays : spottingDays).addAll(
        p.days.where((d) => !d.isAfter(today)),
      );
    }
    // Legacy daily observations are visible, but never become cycle starts.
    for (final d in snapshot.days.values.where((d) => !d.date.isAfter(today))) {
      final flow = d.selections['flow'] ?? {};
      if (flow.contains('spotting')) spottingDays.add(d.date);
      if (flow.any({'light', 'medium', 'heavy'}.contains))
        periodDays.add(d.date);
    }
    return CycleSummary(
      today: today,
      currentStart: start,
      currentCycleDay: start == null
          ? null
          : calendarDaysBetween(start, today) + 1,
      completedCycleCount: periods.isEmpty ? 0 : periods.length - 1,
      eligibleCycleCount: lengths.length,
      estimatedCycleLength: estimate,
      averageCycleLength: _average(lengths),
      averagePeriodLength: _average(periodLengths),
      completedPeriodCount: periodLengths.length,
      predictedNextStart: estimate == null
          ? null
          : addCalendarDays(start!, estimate),
      historicalRangeStart: personal
          ? addCalendarDays(start!, used.first)
          : null,
      historicalRangeEnd: personal ? addCalendarDays(start!, used.last) : null,
      predictionStatus: status,
      entryDays: snapshot.entryDays,
      periodDays: periodDays,
      spottingDays: spottingDays,
    );
  }

  double? _average(List<int> lengths) => lengths.isEmpty
      ? null
      : lengths.reduce((sum, length) => sum + length) / lengths.length;
}
