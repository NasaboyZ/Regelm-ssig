import '../models/day_entry.dart';
import '../models/period_entry.dart';

/// Invented observations covering 365 calendar days, relative to [today].
/// Fixed intervals make the expected forecast independently reproducible.
TrackingSnapshot createCycleDemoData(DateTime today) {
  final end = localDay(today);
  final firstDay = addCalendarDays(end, -364);
  const lengths = [26, 28, 30, 27, 29, 28, 26, 30, 27, 29, 28, 31];
  var start = addCalendarDays(end, -358);
  final periods = <PeriodEntry>[];
  for (var i = 0; i <= lengths.length; i++) {
    periods.add(
      PeriodEntry(
        id: 'demo-period-$i',
        start: start,
        end: addCalendarDays(start, 3 + i % 3),
      ),
    );
    if (i == 2 || i == 6 || i == 10) {
      periods.add(
        PeriodEntry(
          id: 'demo-spotting-$i',
          start: addCalendarDays(start, 10),
          end: addCalendarDays(start, 11),
          type: BleedingType.spotting,
        ),
      );
    }
    if (i < lengths.length) start = addCalendarDays(start, lengths[i]);
  }

  final days = <DateTime, DayEntry>{};
  for (var i = 0; i < 365; i++) {
    final date = addCalendarDays(firstDay, i);
    final bleeding = periods.where((p) => p.contains(date)).firstOrNull;
    // Leave some days empty so the calendar also exercises missing entries.
    if (i % 3 != 0 && bleeding == null && i != 364) continue;
    days[date] = DayEntry(
      date: date,
      selections: {
        'mood': {
          ['calm', 'happy', 'stressed', 'energetic'][i % 4],
        },
        if (bleeding?.type == BleedingType.period)
          'symptoms': {i.isEven ? 'cramps' : 'fatigue'},
      },
      note: i % 14 == 0 || i == 364 ? 'Erfundener Demo-Eintrag' : '',
      temperature: i % 3 == 0 ? 36.3 + (i % 5) / 10 : null,
      weight: i % 14 == 0 ? 64 + (i % 4) / 10 : null,
    );
  }
  return TrackingSnapshot(
    days: days,
    periods: periods,
    forecastConsent: ForecastConsent.yes,
  );
}
