import 'package:flutter/material.dart';
import '../../models/day_entry.dart';
import '../../models/tracking_catalog.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/record_view_model.dart';
import '../../widgets/cycle/cycle_calendar.dart' show monthNames, sameDay;
import 'appointment_dialog.dart';

const _line = Color(0xFFE7E3E3);
const _teal = Color(0xFF579F9E);
const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

class RecordView extends StatefulWidget {
  const RecordView({super.key, required this.viewModel});
  final RecordViewModel viewModel;
  @override
  State<RecordView> createState() => _RecordViewState();
}

class _RecordViewState extends State<RecordView> {
  RecordViewModel get vm => widget.viewModel;
  final Set<String> _expanded = {'mood'};
  int _formRevision = 0;
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    vm.load();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (await vm.save() && mounted) {
      final message =
          vm.reminderWarning ?? 'Deine Einträge wurden gespeichert.';
      setState(() => _leaving = true);
      // Let PopScope observe the completed save before closing the route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context);
      });
    } else if (mounted && vm.saveError != null) {
      setState(() => _expanded.add('measurements'));
    }
  }

  Future<void> _close() async {
    if (vm.isSaving || _leaving) return;
    if (!vm.isDirty) {
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Änderungen speichern?'),
        content: const Text(
          'Deine Eingaben für alle bearbeiteten Tage sind noch nicht gespeichert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Weiter erfassen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save();
    }
    if (action == 'discard') {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _addText({String? categoryId}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TextEntryDialog(
        title: categoryId == null
            ? 'Eigene Kategorie erstellen'
            : 'Eigenen Eintrag hinzufügen',
        label: categoryId == null ? 'Name der Kategorie' : 'Dein Eintrag',
        onSubmit: (value) {
          final error = categoryId == null
              ? vm.addCategory(value)
              : vm.addCustomValue(categoryId, value);
          if (error == null && categoryId == null) {
            _expanded.add(vm.customCategories.keys.last);
          }
          return error;
        },
      ),
    );
  }

  Future<void> _appointment([DayAppointment? appointment]) async {
    final result = await showDialog<DayAppointment>(
      context: context,
      builder: (_) =>
          AppointmentDialog(date: vm.selectedDay, appointment: appointment),
    );
    if (result != null && mounted) vm.putAppointment(result);
  }

  Future<void> _clearDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag leeren?'),
        content: const Text(
          'Alle Angaben für den ausgewählten Tag werden entfernt. Die Änderung wird erst beim Speichern übernommen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tag leeren'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _formRevision++;
        vm.clearDay();
      });
    }
  }

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: vm.selectedDay,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: 'Tag erfassen',
      cancelText: 'Abbrechen',
      confirmText: 'Auswählen',
    );
    if (date != null && mounted) vm.selectDay(date);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final date = vm.selectedDay;
      final today = sameDay(date, DateTime.now());
      return PopScope(
        canPop: _leaving || (!vm.isDirty && !vm.isSaving),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.backgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Zurück',
              onPressed: vm.isSaving ? null : _close,
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
            centerTitle: true,
            title: InkWell(
              onTap: vm.canEdit ? _pickDay : null,
              child: Column(
                children: [
                  Text(
                    today ? 'Heute erfassen' : 'Tag erfassen',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_weekdays[date.weekday - 1]}, ${date.day}. ${monthNames[date.month - 1]} ${date.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                enabled: vm.canEdit,
                tooltip: 'Weitere Aktionen',
                onSelected: (action) {
                  if (action == 'today') vm.selectDay(DateTime.now());
                  if (action == 'clear') _clearDay();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'today',
                    child: Text('Zu heute springen'),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    enabled: vm.entry.hasData,
                    child: const Text('Tag leeren'),
                  ),
                ],
              ),
            ],
          ),
          body: switch (vm.state) {
            RecordLoading() => const Center(child: CircularProgressIndicator()),
            RecordError(:final message) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: vm.load,
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
            ),
            RecordReady() || RecordSaving() => AbsorbPointer(
              absorbing: vm.isSaving,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    children: [
                      _WeekStrip(viewModel: vm),
                      const Divider(height: 1),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Nur eintragen, was heute relevant ist.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const ValueKey('record-scroll'),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            key: ValueKey('${dayKey(date)}-$_formRevision'),
                            children: [
                              for (final category in trackingCategories)
                                _category(category),
                              for (final category
                                  in vm.customCategories.entries)
                                _category(
                                  TrackingCategory(
                                    category.key,
                                    category.value,
                                    const [],
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _addText(),
                                  style: OutlinedButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: AppColors.fontColor,
                                    side: const BorderSide(
                                      color: Color(0xFFCBC5C5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    minimumSize: const Size(0, 44),
                                  ),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 21,
                                    color: AppColors.muted,
                                  ),
                                  label: const Text(
                                    'Eigene Kategorie erstellen',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _footer(today),
                    ],
                  ),
                ),
              ),
            ),
          },
        ),
      );
    },
  );

  Widget _footer(bool today) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vm.saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                vm.saveError!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          FilledButton(
            onPressed: vm.isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burntOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              vm.isSaving
                  ? 'Wird gespeichert …'
                  : 'Eintrag speichern${vm.entry.count > 0 ? ' · ${vm.entry.count}' : ''}',
            ),
          ),
          TextButton(
            onPressed: vm.isSaving ? null : _close,
            child: Text(
              vm.isDirty
                  ? 'Ohne Speichern schliessen'
                  : today
                  ? 'Für heute nichts eintragen'
                  : 'Für diesen Tag nichts eintragen',
              style: const TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _category(TrackingCategory category) {
    final expanded = _expanded.contains(category.id);
    final count = vm.categoryCount(category);
    final (icon, color) = switch (category.id) {
      'bleeding' => (Icons.water_drop_outlined, AppColors.burntOrange),
      'symptoms' => (Icons.favorite_border, const Color(0xFF9480B1)),
      'sexual' => (Icons.favorite_border, _teal),
      'contraception' => (Icons.medication_outlined, const Color(0xFFBE955B)),
      'tests' => (Icons.science_outlined, const Color(0xFF9480B1)),
      'mood' => (Icons.sentiment_satisfied_alt, AppColors.burntOrange),
      'measurements' => (Icons.monitor_weight_outlined, _teal),
      'appointments' => (
        Icons.calendar_today_outlined,
        const Color(0xFFBE955B),
      ),
      'notes' => (Icons.description_outlined, const Color(0xFF9480B1)),
      _ => (Icons.add_circle_outline, _teal),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .65),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              key: ValueKey('category-${category.id}'),
              onTap: () => setState(() {
                expanded
                    ? _expanded.remove(category.id)
                    : _expanded.add(category.id);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 23),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        category.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(left: 6, right: 10),
                        decoration: BoxDecoration(
                          color: AppColors.burntOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in category.groups) ...[
                    if (group.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final option in group.options)
                          _option(group, option),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (category.id == 'notes')
                    TextFormField(
                      key: const ValueKey('day-note'),
                      initialValue: vm.entry.note,
                      onChanged: vm.setNote,
                      minLines: 3,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Was möchtest du dir merken?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (category.id == 'measurements') ...[
                    _measurement('temperature', 'Temperatur', '°C'),
                    const SizedBox(height: 12),
                    _measurement('weight', 'Gewicht', 'kg'),
                  ],
                  if (category.id == 'appointments') ...[
                    for (final appointment in vm.entry.appointments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(appointment.title),
                        subtitle: Text(
                          '${appointment.startsAt.day}.${appointment.startsAt.month}.${appointment.startsAt.year} · ${appointment.startsAt.hour.toString().padLeft(2, '0')}:${appointment.startsAt.minute.toString().padLeft(2, '0')}${appointment.location.isEmpty ? '' : '\n${appointment.location}'}${appointment.alarmMinutes == null ? '' : '\nAlarm: ${appointment.alarmMinutes == 0 ? 'zum Termin' : '${appointment.alarmMinutes} Min. vorher'}'}',
                        ),
                        onTap: () => _appointment(appointment),
                        trailing: IconButton(
                          tooltip: 'Termin entfernen',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => vm.removeAppointment(appointment.id),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _appointment(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Termin hinzufügen'),
                    ),
                  ],
                  if ((vm.entry.customValues[category.id] ?? []).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final value
                              in vm.entry.customValues[category.id]!)
                            InputChip(
                              label: Text(value),
                              backgroundColor: AppColors.pluto,
                              onDeleted: () =>
                                  vm.removeCustomValue(category.id, value),
                              deleteButtonTooltipMessage: 'Eintrag entfernen',
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _addText(categoryId: category.id),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: AppColors.burntOrange,
                      side: const BorderSide(color: AppColors.burntOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 19),
                    label: Text(
                      category.id == 'mood'
                          ? 'Eigene Stimmung hinzufügen'
                          : 'Eigenen Eintrag hinzufügen',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _measurement(String field, String label, String unit) => TextFormField(
    key: ValueKey(field),
    initialValue: vm.measurementInput(field),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    onChanged: (v) => vm.setMeasurement(field, v),
    decoration: InputDecoration(
      labelText: label,
      suffixText: unit,
      border: const OutlineInputBorder(),
      errorText: vm.measurementError(field, vm.measurementInput(field)),
    ),
  );

  Widget _option(TrackingGroup group, TrackingOption option) {
    final selected =
        vm.entry.selections[group.id]?.contains(option.code) ?? false;
    return FilterChip(
      key: ValueKey('${group.id}-${option.code}'),
      label: Text(option.label),
      selected: selected,
      onSelected: (_) => vm.toggle(group, option.code),
      showCheckmark: false,
      selectedColor: option.code == 'energetic'
          ? AppColors.pluto
          : AppColors.burntOrange,
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: selected ? Colors.transparent : const Color(0xFFD7D0D0),
      ),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected && option.code != 'energetic'
            ? Colors.white
            : AppColors.fontColor,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.viewModel});
  final RecordViewModel viewModel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
    child: Row(
      children: [
        SizedBox(
          width: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Vorherige Woche',
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: () => viewModel.moveWeek(-1),
          ),
        ),
        for (final date in viewModel.week) Expanded(child: _day(date)),
        SizedBox(
          width: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Nächste Woche',
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: () => viewModel.moveWeek(1),
          ),
        ),
      ],
    ),
  );
  Widget _day(DateTime date) {
    final selected = date == viewModel.selectedDay;
    final tracked = viewModel.entryDays.contains(date);
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${date.day}.${date.month}.${date.year}${tracked ? ', Eintrag vorhanden' : ', Keine Einträge'}',
      child: InkWell(
        key: ValueKey('record-day-${dayKey(date)}'),
        onTap: () => viewModel.selectDay(date),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Text(
                _weekdays[date.weekday - 1].substring(0, 2),
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? AppColors.burntOrange : AppColors.muted,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 43,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.burntOrange : null,
                  border: Border.all(
                    color: selected ? AppColors.burntOrange : _line,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                    '${date.day}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      color: selected ? Colors.white : AppColors.fontColor,
                    ),
                  ))),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 5,
                      child: tracked
                          ? Container(
                              key: ValueKey('tracking-dot-${dayKey(date)}'),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? Colors.white : _teal,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.onSubmit,
  });
  final String title;
  final String label;
  final String? Function(String) onSubmit;
  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  String _value = '';
  String? _error;
  void _submit() {
    final error = widget.onSubmit(_value);
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      autofocus: true,
      maxLength: 120,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
      onChanged: (v) => _value = v,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Hinzufügen')),
    ],
  );
}
