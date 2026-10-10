import 'cycle_view_model.dart';

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

/// Calendar navigation and data stay independent of Flutter widgets.
class CycleHistoryViewModel extends CycleViewModel {
  CycleHistoryViewModel({
    super.repository,
    super.calculator,
    DateTime Function()? clock,
    Set<DateTime> periodDays = const {},
    Set<DateTime> predictedDays = const {},
    Set<DateTime> entryDays = const {},
  }) : _periodDays = Set.unmodifiable(periodDays.map(_date)),
       _predictedDays = Set.unmodifiable(predictedDays.map(_date)),
       _entryDays = Set.unmodifiable(entryDays.map(_date)),
       super(clock: clock) {
    final now = today;
    _month = DateTime(now.year, now.month);
  }

  final Set<DateTime> _periodDays;
  final Set<DateTime> _predictedDays;
  Set<DateTime> get periodDays =>
      repository == null ? _periodDays : summary.periodDays;
  Set<DateTime> get predictedDays =>
      repository == null ? _predictedDays : summary.predictedDays;
  Set<DateTime> get spottingDays => summary.spottingDays;
  Set<DateTime> _entryDays;
  Set<DateTime> get entryDays =>
      repository == null ? _entryDays : summary.entryDays;
  void setEntryDays(Set<DateTime> days) {
    _entryDays = Set.unmodifiable(days.map(_date));
    notifyListeners();
  }

  late DateTime _month;
  DateTime? _selectedDay;
  DateTime? get selectedDay => _selectedDay;
  DateTime get today => _date(clock());
  DateTime get month => _month;
  bool get hasEntries => periodDays.isNotEmpty || entryDays.isNotEmpty;
  List<DateTime> get nearbyMonths => List.generate(
    5,
    (index) => DateTime(month.year, month.month + index - 1),
  );

  void selectMonth(DateTime value) {
    final next = DateTime(value.year, value.month);
    if (next == _month) return;
    _month = next;
    notifyListeners();
  }

  void previousMonth() => selectMonth(DateTime(month.year, month.month - 1));
  void nextMonth() => selectMonth(DateTime(month.year, month.month + 1));
  void selectDay(DateTime value) {
    final day = _date(value);
    if (_selectedDay == day) return;
    _selectedDay = day;
    _month = DateTime(day.year, day.month);
    notifyListeners();
  }

  void showToday() {
    _selectedDay = today;
    _month = DateTime(today.year, today.month);
    notifyListeners();
  }
}
