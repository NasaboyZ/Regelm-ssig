import 'calendar_date.dart';

enum PredictionStatus { missingStart, disabled, general, personal }

class CycleSummary {
  CycleSummary({
    required this.today,
    required this.currentStart,
    required this.currentCycleDay,
    required this.completedCycleCount,
    required this.eligibleCycleCount,
    required this.estimatedCycleLength,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.completedPeriodCount,
    required this.predictedNextStart,
    required this.historicalRangeStart,
    required this.historicalRangeEnd,
    required this.predictionStatus,
    required Set<DateTime> entryDays,
    required Set<DateTime> periodDays,
    required Set<DateTime> spottingDays,
  }) : entryDays = Set.unmodifiable(entryDays),
       periodDays = Set.unmodifiable(periodDays),
       spottingDays = Set.unmodifiable(spottingDays);
  final DateTime today;
  final DateTime? currentStart;
  final int? currentCycleDay;
  final int completedCycleCount;
  final int eligibleCycleCount;
  final int? estimatedCycleLength;

  /// Arithmetic means of recorded intervals and periods with a known end.
  /// These describe observations independently of forecast consent.
  final double? averageCycleLength;
  final double? averagePeriodLength;
  final int completedPeriodCount;
  final DateTime? predictedNextStart;
  final DateTime? historicalRangeStart;
  final DateTime? historicalRangeEnd;
  final PredictionStatus predictionStatus;
  final Set<DateTime> entryDays;
  final Set<DateTime> periodDays;
  final Set<DateTime> spottingDays;
  Set<DateTime> get predictedDays => {
    if (predictedNextStart != null) predictedNextStart!,
  };
  int? get daysUntilPredictedStart => predictedNextStart == null
      ? null
      : calendarDaysBetween(today, predictedNextStart!);
  DateTime? get latestEntryDay {
    final dates = entryDays.where((d) => !d.isAfter(today)).toList()..sort();
    return dates.isEmpty ? null : dates.last;
  }

  String get predictionExplanation => switch (predictionStatus) {
    PredictionStatus.missingStart => 'Periodenbeginn erfassen',
    PredictionStatus.disabled =>
      'Prognose pausiert. Bitte prüfe die Voraussetzungen in den Details.',
    PredictionStatus.general =>
      'Allgemeine Orientierung – noch nicht aus deinen Zyklusdaten berechnet',
    PredictionStatus.personal =>
      'Persönliche Schätzung aus ${eligibleCycleCount.clamp(0, 6)} abgeschlossenen Zyklen',
  };
  String? get countdown {
    final days = daysUntilPredictedStart;
    if (days == null) return null;
    if (days == 0) return 'Geschätzter Periodenbeginn heute';
    if (days < 0)
      return 'Der geschätzte Termin liegt ${-days} ${days == -1 ? 'Tag' : 'Tage'} zurück';
    return 'Nächste Periode voraussichtlich in $days ${days == 1 ? 'Tag' : 'Tagen'}';
  }
}
