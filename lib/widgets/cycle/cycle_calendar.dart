import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

const monthNames = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class CycleCalendar extends StatefulWidget {
  const CycleCalendar({
    super.key,
    required this.today,
    required this.periodDays,
    this.onDaySelected,
  });
  final DateTime today;
  final Set<DateTime> periodDays;
  final ValueChanged<DateTime>? onDaySelected;
  @override
  State<CycleCalendar> createState() => _CycleCalendarState();
}

class _CycleCalendarState extends State<CycleCalendar> {
  late DateTime month = DateTime(widget.today.year, widget.today.month);
  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + count) / 7).ceil() * 7;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${monthNames[month.month - 1]} ${month.year}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            IconButton(
              tooltip: 'Vorheriger Monat',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left, size: 20),
            ),
            IconButton(
              tooltip: 'Nächster Monat',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells ~/ 7; row++)
          Row(
            children: List.generate(7, (column) {
              final day = row * 7 + column - offset + 1;
              if (day < 1 || day > count)
                return const Expanded(child: SizedBox(height: 34));
              final date = DateTime(month.year, month.month, day);
              final period = widget.periodDays.any(
                (value) => sameDay(value, date),
              );
              final today = sameDay(widget.today, date);
              return Expanded(
                child: Semantics(
                  label:
                      '$day. ${monthNames[month.month - 1]} ${month.year}${today ? ', Heute' : ''}${period ? ', Periode' : ''}',
                  selected: today,
                  child: Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: widget.onDaySelected == null
                          ? null
                          : () => widget.onDaySelected!(date),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: period ? AppColors.burntOrange : null,
                          border: today
                              ? Border.all(color: AppColors.fontColor)
                              : null,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 11,
                            color: period ? Colors.white : AppColors.fontColor,
                          ),
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
