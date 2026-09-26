import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:regelmaessig/models/day_entry.dart';
import 'package:regelmaessig/models/tracking_catalog.dart';
import 'package:regelmaessig/repositories/tracking_repository.dart';
import 'package:regelmaessig/services/appointment_reminders.dart';
import 'package:regelmaessig/services/tracking_storage.dart';
import 'package:regelmaessig/viewmodels/record_view_model.dart';
import 'package:regelmaessig/views/main_view.dart';
import 'package:regelmaessig/views/record/record_view.dart';
import 'package:regelmaessig/widgets/cycle/cycle_calendar.dart';

class MemoryStorage implements TrackingStorage {
  TrackingSnapshot? value;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<TrackingSnapshot> read() async {
    if (failRead) throw StateError('Read failed');
    return value ?? TrackingSnapshot();
  }

  @override
  Future<void> write(TrackingSnapshot value) async {
    if (failWrite) throw StateError('Write failed');
    this.value = value;
  }
}

class FakeReminders implements AppointmentReminders {
  TrackingSnapshot? scheduled;
  @override
  Future<String?> synchronize(TrackingSnapshot snapshot) async {
    scheduled = snapshot;
    return null;
  }
}

TrackingGroup group(String id) =>
    trackingCategories.expand((c) => c.groups).singleWhere((g) => g.id == id);

void main() {
  late MemoryStorage storage;
  late TrackingRepository repository;
  late FakeReminders reminders;
  late RecordViewModel vm;
  final today = DateTime(2026, 9, 18);
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    storage = MemoryStorage();
    repository = TrackingRepository(storage);
    reminders = FakeReminders();
    vm = RecordViewModel(
      repository: repository,
      reminders: reminders,
      date: today,
    );
  });
  tearDown(() {
    vm.dispose();
    repository.dispose();
  });

  test(
    'dots reflect actual data, including drafts and removal of the last value',
    () async {
      await vm.load();
      expect(vm.entryDays, isEmpty);
      vm.addCategory('Schlaf');
      expect(vm.entryDays, isEmpty);
      vm.toggle(group('mood'), 'calm');
      expect(vm.entryDays, {today});
      vm.toggle(group('mood'), 'calm');
      expect(vm.entryDays, isEmpty);
      vm.setNote('   ');
      expect(vm.entryDays, isEmpty);
      vm.addCustomValue(vm.customCategories.keys.single, '8 Stunden');
      expect(vm.entryDays, {today});
      vm.clearDay();
      expect(vm.entryDays, isEmpty);
    },
  );

  test(
    'single and multiple choices can be selected, replaced and cleared',
    () async {
      await vm.load();
      for (final category in trackingCategories) {
        for (final g in category.groups) {
          for (final option in g.options) {
            vm.toggle(g, option.code);
          }
          expect(
            vm.entry.selections[g.id]!.length,
            g.single ? 1 : g.options.length,
          );
        }
      }
      vm.toggle(group('flow'), 'heavy');
      expect(vm.entry.selections['flow'], isEmpty);
      vm.toggle(group('flow'), 'unknown');
      expect(vm.entry.selections['flow'], isEmpty);
    },
  );

  test(
    'all fields and multiple days survive save and a fresh repository load',
    () async {
      await vm.load();
      for (final category in trackingCategories) {
        vm.addCustomValue(category.id, 'Eigener Wert für ${category.title}');
      }
      vm.toggle(group('flow'), 'medium');
      vm.toggle(group('products'), 'cup');
      vm.setNote('Tagesnotiz');
      vm.setMeasurement('temperature', '36,7');
      vm.setMeasurement('weight', '62.5');
      vm.addCategory('Schlaf');
      vm.addCustomValue(vm.customCategories.keys.single, 'Gut geschlafen');
      vm.putAppointment(
        DayAppointment(
          id: 'a',
          title: 'Termin 1',
          location: 'Zürich',
          startsAt: DateTime(2026, 9, 18, 9),
          alarmMinutes: 15,
        ),
      );
      vm.putAppointment(
        DayAppointment(
          id: 'b',
          title: 'Termin 2',
          startsAt: DateTime(2026, 9, 18, 15),
        ),
      );
      vm.selectDay(DateTime(2026, 9, 19));
      vm.toggle(group('mood'), 'energetic');
      vm.selectDay(today);
      expect(vm.entry.appointments, hasLength(2));
      expect(vm.entry.temperature, 36.7);
      expect(await vm.save(), isTrue);
      final restored = TrackingRepository(storage);
      await restored.load();
      expect(restored.snapshot.toJson(), repository.snapshot.toJson());
      expect(restored.snapshot.entryDays, {today, DateTime(2026, 9, 19)});
      expect(
        restored.snapshot.days[today]!.appointments.first.alarmMinutes,
        15,
      );
      expect(restored.snapshot.days[today]!.customValues, hasLength(10));
      expect(reminders.scheduled!.entryDays, restored.snapshot.entryDays);
      restored.dispose();
    },
  );

  test(
    'appointment date changes move the data and marker to the correct day',
    () async {
      await vm.load();
      vm.putAppointment(
        DayAppointment(id: 'a', title: 'Termin', startsAt: today),
      );
      vm.putAppointment(
        DayAppointment(
          id: 'a',
          title: 'Verschoben',
          startsAt: DateTime(2026, 9, 20, 12),
        ),
      );
      expect(vm.selectedDay, DateTime(2026, 9, 20));
      expect(vm.entryDays, {DateTime(2026, 9, 20)});
      vm.removeAppointment('a');
      expect(vm.entryDays, isEmpty);
    },
  );

  test(
    'invalid measurements block save without persisting invalid data',
    () async {
      await vm.load();
      vm.setMeasurement('weight', '-1');
      vm.selectDay(DateTime(2026, 9, 19));
      vm.setNote('Andere Eingabe');
      expect(await vm.save(), isFalse);
      expect(vm.selectedDay, today);
      expect(storage.value, isNull);
      vm.setMeasurement('weight', 'NaN');
      expect(await vm.save(), isFalse);
      vm.setMeasurement('weight', '70,2');
      vm.setMeasurement('temperature', 'Infinity');
      expect(await vm.save(), isFalse);
      vm.setMeasurement('temperature', '');
      expect(await vm.save(), isTrue);
      vm.setMeasurement('weight', '');
      expect(vm.entryDays, {DateTime(2026, 9, 19)});
    },
  );

  test(
    'failed writes retain drafts; clearing a saved day removes its marker',
    () async {
      await vm.load();
      vm.setNote('Behalten');
      storage.failWrite = true;
      expect(await vm.save(), isFalse);
      expect(vm.entry.note, 'Behalten');
      expect(vm.isDirty, isTrue);
      expect(repository.snapshot.entryDays, isEmpty);
      storage.failWrite = false;
      expect(await vm.save(), isTrue);
      vm.clearDay();
      expect(await vm.save(), isTrue);
      expect(repository.snapshot.entryDays, isEmpty);
      expect(storage.value!.days, isEmpty);
    },
  );

  test('read failure prevents saving and can be retried', () async {
    storage.failRead = true;
    await vm.load();
    expect(vm.state, isA<RecordError>());
    expect(await vm.save(), isFalse);
    storage.failRead = false;
    await vm.load();
    expect(vm.state, isA<RecordReady>());
  });

  test(
    'week navigation crosses month and year boundaries without mixing entries',
    () async {
      await vm.load();
      vm.selectDay(DateTime(2026, 12, 31));
      vm.setNote('Silvester');
      expect(vm.week.first, DateTime(2026, 12, 28));
      expect(vm.week.last, DateTime(2027, 1, 3));
      vm.moveWeek(1);
      expect(vm.selectedDay, DateTime(2027, 1, 7));
      expect(vm.entry.hasData, isFalse);
      vm.moveWeek(-1);
      expect(vm.entry.note, 'Silvester');
    },
  );

  testWidgets(
    'today button opens editor, draft dots update, save refreshes home',
    (tester) async {
      tester.view.physicalSize = const Size(403, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MainView(trackingRepository: repository, reminders: reminders),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Heute erfassen'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordView), findsOneWidget);
      final dot = find.byKey(
        ValueKey('tracking-dot-${dayKey(DateTime.now())}'),
      );
      expect(dot, findsNothing);
      await tester.tap(find.text('Ruhig'));
      await tester.pump();
      expect(dot, findsOneWidget);
      await tester.tap(find.text('Ruhig'));
      await tester.pump();
      expect(dot, findsNothing);
      await tester.tap(find.text('Energiegeladen'));
      await tester.pump();
      await tester.tap(find.text('Eintrag speichern · 1'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordView), findsNothing);
      expect(
        tester.widget<CycleCalendar>(find.byType(CycleCalendar)).entryDays,
        {localDay(DateTime.now())},
      );
      await tester.tap(find.text('Heute erfassen'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('mood-energetic')))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'custom category is empty until its first custom value; back protects drafts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RecordView(viewModel: vm),
                  ),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Eigene Kategorie erstellen'));
      await tester.tap(find.text('Eigene Kategorie erstellen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Schlaf');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(vm.entryDays, isEmpty);
      final customId = vm.customCategories.keys.single;
      expect(find.byKey(ValueKey('category-$customId')), findsOneWidget);
      await tester.ensureVisible(find.text('Eigenen Eintrag hinzufügen').last);
      await tester.tap(find.text('Eigenen Eintrag hinzufügen').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '8 Stunden');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(vm.entryDays, {today});
      await tester.tap(find.byTooltip('Zurück'));
      await tester.pumpAndSettle();
      expect(find.text('Änderungen speichern?'), findsOneWidget);
      await tester.tap(find.text('Weiter erfassen'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'day strip swipes in both directions and preserves dated entries',
    (tester) async {
      tester.view.physicalSize = const Size(403, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: RecordView(viewModel: vm)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruhig'));
      await tester.pump();

      final strip = find.byKey(const ValueKey('record-day-strip'));
      Finder day(DateTime date) =>
          find.byKey(ValueKey('record-day-${dayKey(date)}'));
      final next = DateTime(2026, 9, 24);
      await tester.drag(strip, const Offset(-300, 0));
      await tester.pumpAndSettle();
      // Scrolling browses dates; tapping explicitly selects a day.
      expect(vm.selectedDay, today);
      expect(day(next).hitTestable(), findsOneWidget);
      await tester.tap(day(next));
      await tester.pumpAndSettle();
      expect(vm.selectedDay, next);
      expect(vm.entry.hasData, isFalse);
      expect(vm.entryDays, {today});

      await tester.drag(strip, const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.tap(day(today));
      await tester.pumpAndSettle();
      expect(vm.entry.selections['mood'], {'calm'});
      expect(
        find.byKey(ValueKey('tracking-dot-${dayKey(today)}')),
        findsOneWidget,
      );

      // External navigation reveals its selected date; swiping crosses years.
      vm.selectDay(DateTime(2026, 12, 31));
      await tester.pumpAndSettle();
      expect(day(DateTime(2026, 12, 31)).hitTestable(), findsOneWidget);
      await tester.drag(strip, const Offset(-200, 0));
      await tester.pumpAndSettle();
      final january = DateTime(2027, 1, 4);
      expect(day(january).hitTestable(), findsOneWidget);
      await tester.tap(day(january));
      await tester.pumpAndSettle();
      expect(vm.selectedDay, january);
      expect(vm.entryDays, {today});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editor fits narrow screens with enlarged text and validates measurements',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RecordView(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('category-measurements')),
      );
      await tester.tap(find.byKey(const ValueKey('category-measurements')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('temperature')));
      await tester.enterText(find.byKey(const ValueKey('temperature')), 'abc');
      await tester.pump();
      expect(find.text('Bitte gib eine gültige Zahl ein.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
