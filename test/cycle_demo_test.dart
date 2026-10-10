import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:regelmaessig/debug/cycle_demo_data.dart';
import 'package:regelmaessig/debug/demo_tracking_storage.dart';
import 'package:regelmaessig/models/cycle_summary.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/models/period_entry.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/appointment_reminders.dart';
import 'package:regelmaessig/services/cycle_calculation_service.dart';
import 'package:regelmaessig/viewmodels/cycle_history_view_model.dart';
import 'package:regelmaessig/viewmodels/home_view_model.dart';
import 'package:regelmaessig/viewmodels/record_view_model.dart';

class _NoReminders implements AppointmentReminders {
  @override
  Future<String?> synchronize(TrackingSnapshot snapshot) async => null;
}

void main() {
  final today = DateTime(2026, 10, 3);
  const calculator = CycleCalculationService();

  test('Year data is valid, reproducible and survives JSON serialization', () {
    final data = createCycleDemoData(today);
    expect(validatePeriods(data.periods, today: today), isNull);
    expect(data.days.keys.first, DateTime(2025, 10, 4));
    expect(data.days.keys.last, today);
    expect(data.entryDays.every((d) => !d.isAfter(today)), isTrue);
    expect(
      data.periods.where((p) => p.type == BleedingType.period),
      hasLength(13),
    );
    expect(
      data.periods.where((p) => p.type == BleedingType.spotting),
      hasLength(3),
    );
    final json = jsonEncode(data.toJson());
    expect(jsonEncode(createCycleDemoData(today).toJson()), json);
    final restored = TrackingSnapshot.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    expect(restored.toJson(), data.toJson());
  });

  test('Last six cycles yield the documented median and calendar dates', () {
    final summary = calculator.calculate(createCycleDemoData(today), today);
    // Last six intervals: 26, 30, 27, 29, 28, 31.
    // Sorted middle pair: 28, 29; 28.5 rounds to 29.
    expect(summary.completedCycleCount, 12);
    expect(summary.eligibleCycleCount, 12);
    expect(summary.predictionStatus, PredictionStatus.personal);
    expect(summary.currentStart, DateTime(2026, 9, 14));
    expect(summary.currentCycleDay, 20);
    expect(summary.estimatedCycleLength, 29);
    expect(summary.averageCycleLength, 28.25);
    expect(summary.averagePeriodLength, closeTo(64 / 13, 0.0001));
    expect(summary.completedPeriodCount, 13);
    expect(summary.predictedNextStart, DateTime(2026, 10, 13));
    expect(summary.daysUntilPredictedStart, 10);
    expect(summary.historicalRangeStart, DateTime(2026, 10, 10));
    expect(summary.historicalRangeEnd, DateTime(2026, 10, 15));
    expect(summary.spottingDays, hasLength(6));
    expect(summary.periodDays.intersection(summary.spottingDays), isEmpty);
  });

  test('A marked gap excludes that interval from the forecast', () {
    final data = createCycleDemoData(today);
    final periods = data.periods
        .map(
          (p) => PeriodEntry(
            id: p.id,
            start: p.start,
            end: p.end,
            type: p.type,
            gapBefore: p.id == 'demo-period-12',
          ),
        )
        .toList();
    final summary = calculator.calculate(
      data.copyWith(periods: periods),
      today,
    );
    expect(summary.completedCycleCount, 12);
    expect(summary.eligibleCycleCount, 11);
    expect(summary.averageCycleLength, 28);
    expect(summary.estimatedCycleLength, 28);
    expect(summary.predictedNextStart, DateTime(2026, 10, 12));
    expect(summary.historicalRangeEnd, DateTime(2026, 10, 14));
  });

  test(
    'Averages need completed observations and ignore spotting and future ends',
    () {
      final empty = calculator.calculate(TrackingSnapshot(), today);
      expect(empty.averageCycleLength, isNull);
      expect(empty.averagePeriodLength, isNull);
      expect(empty.completedPeriodCount, 0);

      final summary = calculator.calculate(
        TrackingSnapshot(
          periods: [
            PeriodEntry(
              id: 'one-day',
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 1),
            ),
            PeriodEntry(id: 'unknown-end', start: DateTime(2026, 8, 29)),
            PeriodEntry(
              id: 'spotting',
              start: DateTime(2026, 9, 5),
              end: DateTime(2026, 9, 6),
              type: BleedingType.spotting,
            ),
            PeriodEntry(
              id: 'future-end',
              start: DateTime(2026, 9, 28),
              end: DateTime(2026, 10, 5),
            ),
            PeriodEntry(
              id: 'future-start',
              start: DateTime(2026, 10, 28),
              end: DateTime(2026, 10, 30),
            ),
          ],
        ),
        today,
      );
      expect(summary.averageCycleLength, 29);
      expect(summary.averagePeriodLength, 1);
      expect(summary.completedPeriodCount, 1);
      expect(summary.predictedNextStart, isNull);
    },
  );

  test('Calendar-day results stay stable across leap years and DST dates', () {
    for (final date in [
      DateTime(2024, 3, 10),
      DateTime(2026, 3, 29),
      DateTime(2026, 10, 25),
    ]) {
      final data = createCycleDemoData(date);
      expect(validatePeriods(data.periods, today: date), isNull);
      final summary = calculator.calculate(data, date);
      expect(summary.currentCycleDay, 20);
      expect(summary.daysUntilPredictedStart, 10);
      expect(summary.estimatedCycleLength, 29);
      expect(calendarDaysBetween(data.days.keys.first, date), 364);
    }
  });

  test(
    'Record edits update home and calendar through the repository',
    () async {
      final storage = DemoTrackingStorage(createCycleDemoData(today));
      final repository = TrackingRepository(storage);
      final home = HomeViewModel(repository: repository, clock: () => today);
      final calendar = CycleHistoryViewModel(
        repository: repository,
        clock: () => today,
      );
      final record = RecordViewModel(
        repository: repository,
        reminders: _NoReminders(),
        date: today,
        clock: () => today,
      );
      addTearDown(() {
        record.dispose();
        calendar.dispose();
        home.dispose();
        repository.dispose();
      });
      await Future.wait([home.load(), calendar.load(), record.load()]);
      expect(home.summary.currentCycleDay, 20);
      expect(calendar.summary.predictedNextStart, DateTime(2026, 10, 13));
      expect(
        record.putPeriod(PeriodEntry(id: 'new-period', start: today)),
        isNull,
      );
      expect(await record.save(), isTrue);
      expect(home.summary.currentCycleDay, 1);
      expect(home.summary.completedCycleCount, 13);
      expect(home.summary.averageCycleLength, closeTo(358 / 13, 0.0001));
      // A start without a known end must not become a one-day period average.
      expect(home.summary.completedPeriodCount, 13);
      expect(home.summary.averagePeriodLength, closeTo(64 / 13, 0.0001));
      expect(home.summary.predictedNextStart, DateTime(2026, 11, 1));
      expect(calendar.periodDays, contains(today));
      expect(calendar.predictedDays, {DateTime(2026, 11, 1)});
      expect((await storage.read()).periods, hasLength(17));

      await home.setForecastConsent(ForecastConsent.no);
      expect(home.summary.predictionStatus, PredictionStatus.disabled);
      expect(home.summary.averageCycleLength, closeTo(358 / 13, 0.0001));
      expect(home.summary.averagePeriodLength, closeTo(64 / 13, 0.0001));
      expect(calendar.predictedDays, isEmpty);
      expect(calendar.periodDays, contains(today));
    },
  );
}
