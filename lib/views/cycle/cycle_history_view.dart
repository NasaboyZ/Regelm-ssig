import 'package:flutter/material.dart';

import '../../viewmodels/cycle_history_view_model.dart';
import '../../widgets/cycle/cycle_calendar.dart' show monthNames, sameDay;

const _orange = Color(0xFFD65D27);
const _purple = Color(0xFF9076CF);
const _muted = Color(0xFF626775);
const _line = Color(0xFFE8E7EB);
const _shortMonths = [
  'Jan',
  'Feb',
  'Mär',
  'Apr',
  'Mai',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Okt',
  'Nov',
  'Dez',
];

class CycleHistoryView extends StatelessWidget {
  const CycleHistoryView({super.key, required this.viewModel});
  final CycleHistoryViewModel viewModel;

  Future<void> _chooseMonth(BuildContext context) async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(month: viewModel.month),
    );
    if (selected != null) viewModel.selectMonth(selected);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zyklusverlauf',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'Deine Einträge und kommenden Vorschauen',
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: viewModel.showToday,
                        style: _buttonStyle,
                        child: const Text(
                          'Heute',
                          style: TextStyle(fontSize: 12, height: 1.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: OutlinedButton.icon(
                          onPressed: () => _chooseMonth(context),
                          style: _buttonStyle,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Monat wählen',
                            style: TextStyle(fontSize: 12, height: 1.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Vorheriger Monat',
                    onPressed: viewModel.previousMonth,
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                ),
                Expanded(child: _MonthStrip(viewModel: viewModel)),
                SizedBox(
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Nächster Monat',
                    onPressed: viewModel.nextMonth,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monthNames[viewModel.month.month - 1]} ${viewModel.month.year}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      for (final day in [
                        'Mo',
                        'Di',
                        'Mi',
                        'Do',
                        'Fr',
                        'Sa',
                        'So',
                      ])
                        Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CalendarGrid(viewModel: viewModel),
                  const SizedBox(height: 24),
                  const Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _Legend('Eingetragen', _orange, filled: true),
                      _Legend('Vorschau', _purple),
                      _Legend('Heute', Colors.black),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vorschauen basieren auf deinen bisherigen Zyklen.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
                  ),
                  if (!viewModel.hasEntries) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Noch keine Einträge',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static final _buttonStyle = OutlinedButton.styleFrom(
    foregroundColor: Colors.black,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    side: const BorderSide(color: Color(0xFF252831)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: const Size(72, 34),
    visualDensity: VisualDensity.compact,
  );
}

/// Scroll position is presentation state; month selection belongs to the VM.
class _MonthStrip extends StatefulWidget {
  const _MonthStrip({required this.viewModel});
  final CycleHistoryViewModel viewModel;

  @override
  State<_MonthStrip> createState() => _MonthStripState();
}

class _MonthStripState extends State<_MonthStrip> {
  static const _extent = 64.0;
  static const _origin = 120000;
  late final DateTime _anchor = widget.viewModel.month;
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: (_origin - 1) * _extent,
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_revealSelection);
  }

  @override
  void didUpdateWidget(covariant _MonthStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_revealSelection);
      widget.viewModel.addListener(_revealSelection);
      _revealSelection();
    }
  }

  void _revealSelection() {
    if (!_controller.hasClients) return;
    final month = widget.viewModel.month;
    final index =
        _origin +
        (month.year - _anchor.year) * 12 +
        month.month -
        _anchor.month;
    _controller.animateTo(
      ((index - 1) * _extent).clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_revealSelection);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView.builder(
      key: const ValueKey('month-strip'),
      controller: _controller,
      scrollDirection: Axis.horizontal,
      itemExtent: _extent,
      itemCount: _origin * 2,
      itemBuilder: (context, index) {
        final month = DateTime(_anchor.year, _anchor.month + index - _origin);
        final selected = month == widget.viewModel.month;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              label: '${monthNames[month.month - 1]} ${month.year}',
              selected: selected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => widget.viewModel.selectMonth(month),
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFBE8DE)
                        : const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? const Color(0xFFFBE0D3) : _line,
                    ),
                  ),
                  child: Text(
                    _shortMonths[month.month - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _orange : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.viewModel});
  final CycleHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final month = viewModel.month;
    final offset = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + count) / 7).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (column) {
              final day = row * 7 + column - offset + 1;
              if (day < 1 || day > count) {
                return const Expanded(child: SizedBox(height: 76));
              }
              final date = DateTime(month.year, month.month, day);
              final period = viewModel.periodDays.contains(date);
              final predicted =
                  !period && viewModel.predictedDays.contains(date);
              final today = sameDay(date, viewModel.today);
              final entry = viewModel.entryDays.contains(date);
              final selected = viewModel.selectedDay == date;
              final previous = viewModel.periodDays.contains(
                DateTime(month.year, month.month, day - 1),
              );
              final next = viewModel.periodDays.contains(
                DateTime(month.year, month.month, day + 1),
              );
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  onTap: () => viewModel.selectDay(date),
                  label:
                      '$day. ${monthNames[month.month - 1]} ${month.year}${today ? ', Heute' : ''}${period ? ', Eingetragen' : ''}${predicted ? ', Vorschau' : ''}${entry ? ', Eintrag vorhanden' : ''}',
                  child: ExcludeSemantics(
                    child: InkWell(
                      key: ValueKey(
                        'day-${date.year}-${date.month}-${date.day}',
                      ),
                      onTap: () => viewModel.selectDay(date),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 76,
                        child: Column(
                          children: [
                            Container(
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: period
                                    ? _orange
                                    : selected
                                    ? const Color(0xFFFBE8DE)
                                    : null,
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(
                                    !previous || column == 0 || day == 1
                                        ? 24
                                        : 0,
                                  ),
                                  right: Radius.circular(
                                    !next || column == 6 || day == count
                                        ? 24
                                        : 0,
                                  ),
                                ),
                              ),
                              child: Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: today || predicted || selected
                                      ? Border.all(
                                          color: today
                                              ? Colors.black
                                              : selected
                                              ? _orange
                                              : _purple,
                                          width: 1.7,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: period ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            if (entry)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF94BDBD),
                                ),
                              ),
                            if (today)
                              const FittedBox(
                                child: Text(
                                  'Heute',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color, {this.filled = false});
  final String label;
  final Color color;
  final bool filled;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : null,
          border: Border.all(color: color, width: 1.5),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF202434)),
      ),
    ],
  );
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.month});
  final DateTime month;
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int year = widget.month.year;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Monat wählen'),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Vorheriges Jahr',
                  onPressed: () => setState(() => year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: Text('$year', textAlign: TextAlign.center)),
                IconButton(
                  tooltip: 'Nächstes Jahr',
                  onPressed: () => setState(() => year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            for (var row = 0; row < 4; row++)
              Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          DateTime(year, row * 3 + col + 1),
                        ),
                        child: Text(_shortMonths[row * 3 + col]),
                      ),
                    ),
                ],
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
    ],
  );
}
