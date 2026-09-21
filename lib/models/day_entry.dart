DateTime localDay(DateTime date) => DateTime(date.year, date.month, date.day);
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class DayAppointment {
  const DayAppointment({
    required this.id,
    required this.title,
    required this.startsAt,
    this.location = '',
    this.alarmMinutes,
  });
  final String id;
  final String title;
  final String location;
  final DateTime startsAt;
  final int? alarmMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'location': location,
    'startsAtUtc': startsAt.toUtc().toIso8601String(),
    'alarmMinutes': alarmMinutes,
  };
  factory DayAppointment.fromJson(Map<String, dynamic> json) => DayAppointment(
    id: json['id'] as String,
    title: json['title'] as String,
    location: json['location'] as String,
    startsAt: DateTime.parse(json['startsAtUtc'] as String).toLocal(),
    alarmMinutes: json['alarmMinutes'] as int?,
  );
}

/// One record per local calendar date. Empty category definitions are not data.
class DayEntry {
  DayEntry({
    required DateTime date,
    Map<String, Set<String>> selections = const {},
    Map<String, List<String>> customValues = const {},
    List<DayAppointment> appointments = const [],
    this.note = '',
    this.temperature,
    this.weight,
  }) : date = localDay(date),
       selections = Map.unmodifiable(
         selections.map((k, v) => MapEntry(k, Set<String>.unmodifiable(v))),
       ),
       customValues = Map.unmodifiable(
         customValues.map((k, v) => MapEntry(k, List<String>.unmodifiable(v))),
       ),
       appointments = List.unmodifiable(appointments);

  final DateTime date;
  final Map<String, Set<String>> selections;
  final Map<String, List<String>> customValues;
  final List<DayAppointment> appointments;
  final String note;
  final double? temperature;
  final double? weight;
  int get count =>
      selections.values.fold<int>(0, (n, v) => n + v.length) +
      customValues.values.fold<int>(
        0,
        (n, v) => n + v.where((s) => s.trim().isNotEmpty).length,
      ) +
      appointments.length +
      (note.trim().isEmpty ? 0 : 1) +
      (temperature == null ? 0 : 1) +
      (weight == null ? 0 : 1);
  bool get hasData => count > 0;

  DayEntry copyWith({
    Map<String, Set<String>>? selections,
    Map<String, List<String>>? customValues,
    List<DayAppointment>? appointments,
    String? note,
    double? temperature,
    double? weight,
    bool clearTemperature = false,
    bool clearWeight = false,
  }) => DayEntry(
    date: date,
    selections: selections ?? this.selections,
    customValues: customValues ?? this.customValues,
    appointments: appointments ?? this.appointments,
    note: note ?? this.note,
    temperature: clearTemperature ? null : temperature ?? this.temperature,
    weight: clearWeight ? null : weight ?? this.weight,
  );

  Map<String, dynamic> toJson() => {
    'date': dayKey(date),
    'selections': selections.map((k, v) => MapEntry(k, v.toList())),
    'customValues': customValues,
    'appointments': appointments.map((v) => v.toJson()).toList(),
    'note': note,
    'temperature': temperature,
    'weight': weight,
  };
  factory DayEntry.fromJson(Map<String, dynamic> json) => DayEntry(
    date: DateTime.parse(json['date'] as String),
    selections: (json['selections'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Set<String>.from(v as List)),
    ),
    customValues: (json['customValues'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, List<String>.from(v as List)),
    ),
    appointments: (json['appointments'] as List)
        .map((v) => DayAppointment.fromJson(v as Map<String, dynamic>))
        .toList(),
    note: json['note'] as String,
    temperature: (json['temperature'] as num?)?.toDouble(),
    weight: (json['weight'] as num?)?.toDouble(),
  );
}

class TrackingSnapshot {
  TrackingSnapshot({
    Map<DateTime, DayEntry> days = const {},
    Map<String, String> categories = const {},
  }) : days = Map.unmodifiable(days),
       categories = Map.unmodifiable(categories);
  final Map<DateTime, DayEntry> days;
  final Map<String, String> categories;
  Set<DateTime> get entryDays =>
      days.entries.where((e) => e.value.hasData).map((e) => e.key).toSet();
  Map<String, dynamic> toJson() => {
    'version': 1,
    'days': days.values.where((d) => d.hasData).map((d) => d.toJson()).toList(),
    'categories': categories,
  };
  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported tracking data version');
    }
    final entries = (json['days'] as List).map(
      (v) => DayEntry.fromJson(v as Map<String, dynamic>),
    );
    return TrackingSnapshot(
      days: {for (final day in entries) day.date: day},
      categories: Map<String, String>.from(json['categories'] as Map),
    );
  }
}
