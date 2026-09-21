import 'package:flutter/material.dart';
import '../../models/day_entry.dart';

class AppointmentDialog extends StatefulWidget {
  const AppointmentDialog({super.key, required this.date, this.appointment});
  final DateTime date;
  final DayAppointment? appointment;
  @override
  State<AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<AppointmentDialog> {
  final _form = GlobalKey<FormState>();
  late String _title = widget.appointment?.title ?? '';
  late String _location = widget.appointment?.location ?? '';
  late DateTime _date = widget.appointment?.startsAt ?? widget.date;
  late TimeOfDay _time = widget.appointment == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.appointment!.startsAt);
  late int? _alarm = widget.appointment?.alarmMinutes;
  String? _error;

  Future<void> _chooseDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: 'Tag wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Übernehmen',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Zeit wählen',
      cancelText: 'Abbrechen',
      confirmText: 'Übernehmen',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final startsAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (_alarm != null &&
        !startsAt
            .subtract(Duration(minutes: _alarm!))
            .isAfter(DateTime.now())) {
      setState(
        () => _error =
            'Die Alarmzeit liegt in der Vergangenheit. Bitte ändere die Zeit oder wähle „Kein Alarm“.',
      );
      return;
    }
    Navigator.pop(
      context,
      DayAppointment(
        id:
            widget.appointment?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.trim(),
        location: _location.trim(),
        startsAt: startsAt,
        alarmMinutes: _alarm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.appointment == null ? 'Termin hinzufügen' : 'Termin bearbeiten',
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titel'),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (v) => _title = v,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Bitte gib einen Titel ein.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _location,
                decoration: const InputDecoration(labelText: 'Ort'),
                onChanged: (v) => _location = v,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _chooseDay,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('Tag: ${_date.day}.${_date.month}.${_date.year}'),
              ),
              OutlinedButton.icon(
                onPressed: _chooseTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  'Zeit: ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _alarm ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Alarm'),
                items: const [
                  DropdownMenuItem(value: -1, child: Text('Kein Alarm')),
                  DropdownMenuItem(value: 0, child: Text('Zum Termin')),
                  DropdownMenuItem(value: 5, child: Text('5 Minuten vorher')),
                  DropdownMenuItem(value: 15, child: Text('15 Minuten vorher')),
                  DropdownMenuItem(value: 30, child: Text('30 Minuten vorher')),
                  DropdownMenuItem(value: 60, child: Text('1 Stunde vorher')),
                  DropdownMenuItem(value: 1440, child: Text('1 Tag vorher')),
                ],
                onChanged: (v) => setState(() {
                  _alarm = v == -1 ? null : v;
                  _error = null;
                }),
              ),
              if (_alarm != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Der Alarm wird beim Speichern deiner Einträge aktiviert. Auf Android kann er systembedingt etwas später erscheinen.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
    ],
  );
}
