import 'package:flutter/material.dart';
import '../../models/day_entry.dart';
import '../../models/period_entry.dart';
import '../../widgets/cycle/cycle_summary_card.dart' show cycleDateLabel;

class PeriodDialog extends StatefulWidget {
  const PeriodDialog({
    super.key,
    required this.date,
    required this.today,
    required this.onSubmit,
    this.entry,
  });
  final DateTime date;
  final DateTime today;
  final PeriodEntry? entry;
  final String? Function(PeriodEntry) onSubmit;
  @override
  State<PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<PeriodDialog> {
  late final String id = widget.entry?.id ?? PeriodEntry.newId();
  late DateTime start =
      widget.entry?.start ??
      (widget.date.isAfter(widget.today)
          ? widget.today
          : localDay(widget.date));
  late DateTime? end = widget.entry?.end;
  late BleedingType type = widget.entry?.type ?? BleedingType.period;
  late bool gap = widget.entry?.gapBefore ?? false;
  String? error;
  Future<void> _pick(bool isEnd) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isEnd ? (end ?? start) : start,
      firstDate: DateTime(1900),
      lastDate: widget.today,
      helpText: isEnd ? 'Letzter Blutungstag' : 'Tatsächlicher Blutungsbeginn',
      cancelText: 'Abbrechen',
      confirmText: 'Auswählen',
    );
    if (date != null && mounted)
      setState(() {
        if (isEnd) {
          end = date;
        } else {
          start = date;
        }
      });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entry == null ? 'Blutung erfassen' : 'Blutung bearbeiten',
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final value in BleedingType.values)
                  ChoiceChip(
                    label: Text(
                      value == BleedingType.period
                          ? 'Periode'
                          : 'Schmierblutung',
                    ),
                    selected: type == value,
                    onSelected: (_) => setState(() => type = value),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => _pick(false),
              child: Text('Beginn: ${cycleDateLabel(start)}'),
            ),
            TextButton(
              onPressed: () => _pick(true),
              child: Text(
                end == null
                    ? 'Letzten Blutungstag angeben (optional)'
                    : 'Letzter Blutungstag: ${cycleDateLabel(end!)}',
              ),
            ),
            if (end != null)
              TextButton(
                onPressed: () => setState(() => end = null),
                child: const Text('Enddatum entfernen'),
              ),
            if (type == BleedingType.period)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Seit der vorherigen erfassten Periode fehlt mindestens eine Periode.',
                  style: TextStyle(fontSize: 13),
                ),
                value: gap,
                onChanged: (value) => setState(() => gap = value ?? false),
              ),
            const Text(
              'Nur tatsächliche Blutungen erfassen. Ein fehlendes Enddatum bleibt unbekannt.',
              style: TextStyle(fontSize: 12),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          final result = widget.onSubmit(
            PeriodEntry(
              id: id,
              start: start,
              end: end,
              type: type,
              gapBefore: type == BleedingType.period && gap,
            ),
          );
          if (result == null) {
            Navigator.pop(context);
          } else {
            setState(() => error = result);
          }
        },
        child: const Text('Übernehmen'),
      ),
    ],
  );
}
