import 'dart:math';
import 'calendar_date.dart';

enum BleedingType { period, spotting }

enum ForecastConsent { unknown, yes, no, unsure }

class PeriodEntry {
  PeriodEntry({
    required this.id,
    required DateTime start,
    DateTime? end,
    this.type = BleedingType.period,
    this.gapBefore = false,
  }) : start = localDay(start),
       end = end == null ? null : localDay(end);

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final String id;
  final DateTime start;
  final DateTime? end;
  final BleedingType type;
  final bool gapBefore;
  bool contains(DateTime date) =>
      !localDay(date).isBefore(start) && !localDay(date).isAfter(end ?? start);
  Iterable<DateTime> get days sync* {
    for (
      var date = start;
      !date.isAfter(end ?? start);
      date = addCalendarDays(date, 1)
    ) {
      yield date;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': dayKey(start),
    'end': end == null ? null : dayKey(end!),
    'type': type.name,
    'gapBefore': gapBefore,
  };
  factory PeriodEntry.fromJson(Map<String, dynamic> json) => PeriodEntry(
    id: json['id'] as String,
    start: parseCalendarDate(json['start'] as String),
    end: json['end'] == null ? null : parseCalendarDate(json['end'] as String),
    type: BleedingType.values.byName(json['type'] as String),
    gapBefore: json['gapBefore'] as bool? ?? false,
  );
}

/// Shared validation for editing and persistence. Unknown ends mean one known day.
String? validatePeriods(List<PeriodEntry> entries, {DateTime? today}) {
  final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
  final ids = <String>{};
  PeriodEntry? previous;
  for (final entry in sorted) {
    if (entry.id.isEmpty || !ids.add(entry.id)) return 'Doppelte Perioden-ID.';
    if (entry.end != null && entry.end!.isBefore(entry.start)) {
      return 'Der letzte Blutungstag darf nicht vor dem Beginn liegen.';
    }
    if (today != null &&
        (entry.start.isAfter(localDay(today)) ||
            (entry.end?.isAfter(localDay(today)) ?? false))) {
      return 'Tatsächliche Blutungen können nicht in der Zukunft liegen.';
    }
    if (previous != null &&
        !entry.start.isAfter(previous.end ?? previous.start)) {
      return 'Diese Blutung überschneidet sich mit einem vorhandenen Eintrag.';
    }
    previous = entry;
  }
  return null;
}
