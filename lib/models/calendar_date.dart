/// Calendar arithmetic deliberately ignores local UTC offsets and DST.
DateTime localDay(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
int calendarDaysBetween(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime parseCalendarDate(String value) {
  final result = DateTime.parse(value);
  if (dayKey(result) != value)
    throw const FormatException('Invalid calendar date');
  return localDay(result);
}
