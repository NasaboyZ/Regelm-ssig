import 'package:flutter/foundation.dart';
import '../models/day_entry.dart';
import '../models/tracking_catalog.dart';
import '../repositories/tracking_repository.dart';
import '../services/appointment_reminders.dart';

sealed class RecordState {
  const RecordState();
}

class RecordLoading extends RecordState {
  const RecordLoading();
}

class RecordReady extends RecordState {
  const RecordReady();
}

class RecordSaving extends RecordState {
  const RecordSaving();
}

class RecordError extends RecordState {
  const RecordError(this.message);
  final String message;
}

class RecordViewModel extends ChangeNotifier {
  RecordViewModel({
    required this.repository,
    required this.reminders,
    DateTime? date,
  }) : _selectedDay = localDay(date ?? DateTime.now());
  final TrackingRepository repository;
  final AppointmentReminders reminders;
  RecordState _state = const RecordLoading();
  RecordState get state => _state;
  DateTime _selectedDay;
  DateTime get selectedDay => _selectedDay;
  final Map<DateTime, DayEntry> _days = {};
  final Map<String, String> _categories = {};
  final Map<String, String> _measurementInputs = {};
  bool _disposed = false;
  bool _dirty = false;
  bool get isDirty => _dirty;
  bool get isSaving => _state is RecordSaving;
  bool get canEdit => _state is RecordReady;
  String? saveError;
  String? reminderWarning;
  DayEntry get entry => _days[selectedDay] ?? DayEntry(date: selectedDay);
  Map<String, String> get customCategories => Map.unmodifiable(_categories);
  Set<DateTime> get entryDays =>
      _days.values.where((d) => d.hasData).map((d) => d.date).toSet();
  List<DateTime> get week {
    final monday = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day - selectedDay.weekday + 1,
    );
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _state = const RecordLoading();
    _notify();
    try {
      await repository.load();
      if (_disposed) return;
      _days
        ..clear()
        ..addAll(repository.snapshot.days);
      _categories
        ..clear()
        ..addAll(repository.snapshot.categories);
      _state = const RecordReady();
    } catch (_) {
      _state = const RecordError(
        'Deine Einträge konnten nicht geladen werden. Bitte versuche es erneut.',
      );
    }
    _notify();
  }

  void selectDay(DateTime value) {
    if (!canEdit) return;
    _selectedDay = localDay(value);
    _notify();
  }

  void moveWeek(int weeks) => selectDay(
    DateTime(selectedDay.year, selectedDay.month, selectedDay.day + weeks * 7),
  );
  void _change(DayEntry day) {
    if (!canEdit) return;
    _days[day.date] = day;
    _dirty = true;
    saveError = null;
    _notify();
  }

  void toggle(TrackingGroup group, String code) {
    if (!group.options.any((o) => o.code == code)) return;
    final values = Set<String>.from(entry.selections[group.id] ?? {});
    if (!values.remove(code)) {
      if (group.single) values.clear();
      values.add(code);
    }
    _change(
      entry.copyWith(selections: {...entry.selections, group.id: values}),
    );
  }

  int categoryCount(TrackingCategory category) {
    var count = category.groups.fold(
      0,
      (n, g) => n + (entry.selections[g.id]?.length ?? 0),
    );
    count += entry.customValues[category.id]?.length ?? 0;
    if (category.id == 'notes' && entry.note.trim().isNotEmpty) count++;
    if (category.id == 'appointments') count += entry.appointments.length;
    if (category.id == 'measurements') {
      count +=
          (entry.temperature == null ? 0 : 1) + (entry.weight == null ? 0 : 1);
    }
    return count;
  }

  String? addCategory(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return 'Bitte gib einen Namen ein.';
    if ([
      ...trackingCategories.map((c) => c.title),
      ..._categories.values,
    ].any((t) => t.toLowerCase() == clean.toLowerCase())) {
      return 'Diese Kategorie gibt es bereits.';
    }
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    _categories[id] = clean;
    _dirty = true;
    _notify();
    return null;
  }

  String? addCustomValue(String categoryId, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Bitte gib einen Eintrag ein.';
    final values = entry.customValues[categoryId] ?? [];
    if (values.any((v) => v.toLowerCase() == clean.toLowerCase())) {
      return 'Dieser Eintrag ist bereits vorhanden.';
    }
    _change(
      entry.copyWith(
        customValues: {
          ...entry.customValues,
          categoryId: [...values, clean],
        },
      ),
    );
    return null;
  }

  void removeCustomValue(String categoryId, String value) => _change(
    entry.copyWith(
      customValues: {
        ...entry.customValues,
        categoryId: (entry.customValues[categoryId] ?? [])
            .where((v) => v != value)
            .toList(),
      },
    ),
  );
  void setNote(String value) => _change(entry.copyWith(note: value));
  String measurementInput(String field) =>
      _measurementInputs['${dayKey(selectedDay)}:$field'] ??
      (field == 'temperature' ? entry.temperature : entry.weight)
          ?.toString()
          .replaceAll('.', ',') ??
      '';
  String? measurementError(String field, String input) {
    if (input.trim().isEmpty) return null;
    final value = double.tryParse(input.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite) {
      return 'Bitte gib eine gültige Zahl ein.';
    }
    if (field == 'weight' && value <= 0) {
      return 'Das Gewicht muss grösser als 0 sein.';
    }
    if (field == 'temperature' && value <= -273.15) {
      return 'Die Temperatur muss über −273,15 °C liegen.';
    }
    return null;
  }

  void setMeasurement(String field, String input) {
    _measurementInputs['${dayKey(selectedDay)}:$field'] = input;
    final value = measurementError(field, input) == null
        ? double.tryParse(input.trim().replaceAll(',', '.'))
        : null;
    _change(
      field == 'temperature'
          ? entry.copyWith(temperature: value, clearTemperature: value == null)
          : entry.copyWith(weight: value, clearWeight: value == null),
    );
  }

  void putAppointment(DayAppointment appointment) {
    if (!canEdit || appointment.title.trim().isEmpty) return;
    // Moving a date transfers the appointment and therefore its tracking dot.
    for (final day in _days.values.toList()) {
      if (day.appointments.any((a) => a.id == appointment.id)) {
        _days[day.date] = day.copyWith(
          appointments: day.appointments
              .where((a) => a.id != appointment.id)
              .toList(),
        );
      }
    }
    final targetDate = localDay(appointment.startsAt);
    final target = _days[targetDate] ?? DayEntry(date: targetDate);
    _selectedDay = targetDate;
    _change(
      target.copyWith(appointments: [...target.appointments, appointment]),
    );
  }

  void removeAppointment(String id) => _change(
    entry.copyWith(
      appointments: entry.appointments.where((a) => a.id != id).toList(),
    ),
  );
  void clearDay() {
    _measurementInputs.removeWhere(
      (key, _) => key.startsWith('${dayKey(selectedDay)}:'),
    );
    _change(DayEntry(date: selectedDay));
  }

  Future<bool> save() async {
    if (!canEdit) return false;
    for (final input in _measurementInputs.entries) {
      if (measurementError(input.key.split(':').last, input.value) != null) {
        _selectedDay = DateTime.parse(input.key.split(':').first);
        saveError =
            'Bitte korrigiere Temperatur oder Gewicht am ausgewählten Tag.';
        _notify();
        return false;
      }
    }
    _state = const RecordSaving();
    saveError = null;
    _notify();
    final snapshot = TrackingSnapshot(
      days: {for (final d in _days.values.where((d) => d.hasData)) d.date: d},
      categories: _categories,
    );
    try {
      await repository.save(snapshot);
    } catch (_) {
      _state = const RecordReady();
      saveError =
          'Speichern fehlgeschlagen. Deine Eingaben bleiben erhalten. Bitte versuche es erneut.';
      _notify();
      return false;
    }
    reminderWarning = await reminders.synchronize(snapshot);
    _dirty = false;
    _state = const RecordReady();
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
