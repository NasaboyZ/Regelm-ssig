class CycleData {
  const CycleData({
    required this.today,
    required this.start,
    this.length = 28,
    this.periodLength = 5,
  });
  final DateTime today;
  final DateTime start;
  final int length;
  final int periodLength;
  int get day => today.difference(start).inDays + 1;
  int get daysUntilPeriod => length - day;
  String get phase => 'Lutealphase';
}
